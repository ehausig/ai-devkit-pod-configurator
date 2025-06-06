#!/bin/bash
set -e

# Configuration
IMAGE_NAME="claude-code"
IMAGE_TAG="latest"
NAMESPACE="claude-code"
TEMP_DIR=".build-temp"
LANGUAGES_CONFIG="languages.conf"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Building Claude Code Container for Kubernetes ===${NC}"

# Check prerequisites
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

if ! command -v colima &> /dev/null; then
    echo -e "${RED}Error: colima is not installed or not in PATH${NC}"
    exit 1
fi

# Function to check if Nexus is available
check_nexus() {
    if curl -s http://localhost:8081 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Nexus detected at http://localhost:8081${NC}"
        return 0
    else
        return 1
    fi
}

# Function to display language selection menu
select_languages() {
    # Clear the screen for better menu display
    clear
    
    echo -e "${BLUE}=== Language Selection ===${NC}"
    echo -e "Select additional languages to include in the container.\n"
    echo -e "${YELLOW}Instructions:${NC}"
    echo -e "  ↑/↓ or j/k = Move cursor"
    echo -e "  SPACE = Toggle selection"
    echo -e "  ENTER = Confirm selections"
    echo -e "  q = Quit without building\n"
    
    # Read available languages from config
    local languages=()
    local display_names=()
    local installations=()
    local selected=()
    
    while IFS='|' read -r lang_id display_name installation; do
        # Skip empty lines and comments
        [[ -z "$lang_id" || "$lang_id" =~ ^# ]] && continue
        
        languages+=("$lang_id")
        display_names+=("$display_name")
        installations+=("$installation")
        selected+=(false)
    done < "$LANGUAGES_CONFIG"
    
    local current=0
    local key=""
    
    # Save cursor position
    tput sc
    
    # Hide cursor
    tput civis
    
    # Initial display
    for i in "${!languages[@]}"; do
        echo ""
    done
    
    # Display menu
    while true; do
        # Restore cursor position
        tput rc
        
        # Display options
        for i in "${!languages[@]}"; do
            # Clear the line
            tput el
            
            if [[ $i -eq $current ]]; then
                echo -ne "${BLUE}▸${NC}"
            else
                echo -ne " "
            fi
            
            if [[ ${selected[$i]} == true ]]; then
                echo -e " ${GREEN}[✓]${NC} ${display_names[$i]}"
            else
                echo -e " [ ] ${display_names[$i]}"
            fi
        done
        
        # Read key - handle both single chars and escape sequences
        IFS= read -rsn1 key
        
        # Handle different key types
        if [[ $key == $'\e' ]]; then
            # Escape sequence (arrow keys)
            read -rsn2 key
            case "$key" in
                "[A"|"OA") # Up arrow
                    ((current > 0)) && ((current--))
                    ;;
                "[B"|"OB") # Down arrow
                    ((current < ${#languages[@]} - 1)) && ((current++))
                    ;;
            esac
        elif [[ ${#key} -eq 0 ]]; then
            # Enter key (empty string)
            break
        elif [[ "$key" == " " ]]; then
            # Space - toggle selection
            if [[ ${selected[$current]} == true ]]; then
                selected[$current]=false
            else
                selected[$current]=true
            fi
        elif [[ "$key" == "k" ]] || [[ "$key" == "K" ]]; then
            # vim-style up
            ((current > 0)) && ((current--))
        elif [[ "$key" == "j" ]] || [[ "$key" == "J" ]]; then
            # vim-style down
            ((current < ${#languages[@]} - 1)) && ((current++))
        elif [[ "$key" == "q" ]] || [[ "$key" == "Q" ]]; then
            # Quit
            tput cnorm
            clear
            echo -e "${YELLOW}Installation cancelled.${NC}"
            exit 0
        fi
    done
    
    # Show cursor
    tput cnorm
    
    # Clear and show results
    clear
    
    # Build installation commands for selected languages
    SELECTED_INSTALLATIONS=""
    echo -e "${GREEN}Selected languages:${NC}"
    local any_selected=false
    
    for i in "${!languages[@]}"; do
        if [[ ${selected[$i]} == true ]]; then
            echo -e "  ✓ ${display_names[$i]}"
            SELECTED_INSTALLATIONS+="\n${installations[$i]}\n"
            any_selected=true
        fi
    done
    
    if [[ $any_selected == false ]]; then
        echo -e "  None (base image only)"
    fi
    
    echo ""
}

# Function to create custom Dockerfile
create_custom_dockerfile() {
    mkdir -p "$TEMP_DIR"
    
    # Copy base Dockerfile
    cp Dockerfile.base "$TEMP_DIR/Dockerfile"
    
    # Insert language installations if any were selected
    if [[ -n "$SELECTED_INSTALLATIONS" ]]; then
        # Create a temporary file with the installations
        echo -e "$SELECTED_INSTALLATIONS" > "$TEMP_DIR/installations.txt"
        
        # Replace placeholder with installations
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/r $TEMP_DIR/installations.txt" "$TEMP_DIR/Dockerfile"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        
        # Clean up
        rm -f "$TEMP_DIR/Dockerfile.bak" "$TEMP_DIR/installations.txt"
    else
        # Just remove the placeholder
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak"
    fi
}

# Function to create Nexus-aware deployment
create_deployment_with_nexus() {
    echo -e "${YELLOW}Creating Nexus-aware Kubernetes deployment...${NC}"
    
    # Create the ConfigMap first
    kubectl apply -f kubernetes/nexus-config.yaml
    
    # Create a proper deployment file with Nexus configuration
    cat > "$TEMP_DIR/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: claude-code
  namespace: claude-code
  labels:
    app: claude-code
spec:
  replicas: 1
  selector:
    matchLabels:
      app: claude-code
  template:
    metadata:
      labels:
        app: claude-code
    spec:
      containers:
      # Main Claude Code container
      - name: claude-code
        image: claude-code:latest
        imagePullPolicy: IfNotPresent
        command: ["sleep", "infinity"]
        volumeMounts:
        # Original volume mounts
        - name: config-volume
          mountPath: /home/claude/.config/claude-code
        - name: workspace-volume
          mountPath: /home/claude/workspace
        # Create a writable .cargo directory
        - name: cargo-dir
          mountPath: /home/claude/.cargo
        # Mount just the config file
        - name: cargo-config
          mountPath: /home/claude/.cargo/config.toml
          subPath: cargo-config.toml
        # Nexus proxy configuration mounts
        - name: pip-config
          mountPath: /home/claude/.config/pip/pip.conf
          subPath: pip.conf
        - name: npm-config
          mountPath: /home/claude/.npmrc
          subPath: npmrc
        env:
        # Python package proxy
        - name: PIP_INDEX_URL
          value: "http://host.lima.internal:8081/repository/pypi-proxy/simple/"
        - name: PIP_TRUSTED_HOST
          value: "host.lima.internal"
        # Node.js package proxy
        - name: NPM_CONFIG_REGISTRY
          value: "http://host.lima.internal:8081/repository/npm-proxy/"
        # Go proxy
        - name: GOPROXY
          value: "http://host.lima.internal:8081/repository/go-proxy/"
        # Rust/Cargo configuration
        - name: CARGO_HOME
          value: "/home/claude/.cargo"
        - name: CARGO_NET_GIT_FETCH_WITH_CLI
          value: "true"
        - name: CARGO_HTTP_CHECK_REVOKE
          value: "false"
        - name: CARGO_HTTP_TIMEOUT
          value: "60"
        # HTTP proxy for cargo
        - name: HTTP_PROXY
          value: "http://host.lima.internal:8081"
        - name: HTTPS_PROXY
          value: "http://host.lima.internal:8081"
        # No proxy for internal Kubernetes communication
        - name: NO_PROXY
          value: "localhost,127.0.0.1,.svc,.cluster.local"
        - name: no_proxy
          value: "localhost,127.0.0.1,.svc,.cluster.local"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      
      # Filebrowser sidecar for easy file management
      - name: filebrowser
        image: filebrowser/filebrowser:latest
        ports:
        - containerPort: 8090
          name: filebrowser
        volumeMounts:
        - name: workspace-volume
          mountPath: /srv
        - name: filebrowser-config
          mountPath: /config
        - name: filebrowser-db
          mountPath: /database
        env:
        - name: FB_DATABASE
          value: /database/filebrowser.db
        - name: FB_CONFIG
          value: /config/settings.json
        - name: FB_ROOT
          value: /srv
        - name: FB_LOG
          value: stdout
        - name: FB_PORT
          value: "8090"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
      
      volumes:
      # Original volumes
      - name: config-volume
        persistentVolumeClaim:
          claimName: claude-code-config-pvc
      - name: workspace-volume
        persistentVolumeClaim:
          claimName: claude-code-workspace-pvc
      # Writable cargo directory
      - name: cargo-dir
        emptyDir: {}
      # Filebrowser volumes
      - name: filebrowser-config
        configMap:
          name: filebrowser-config
      - name: filebrowser-db
        emptyDir: {}
      # Nexus proxy configuration volumes
      - name: pip-config
        configMap:
          name: nexus-proxy-config
          items:
          - key: pip.conf
            path: pip.conf
          defaultMode: 0644
      - name: npm-config
        configMap:
          name: nexus-proxy-config
          items:
          - key: npmrc
            path: npmrc
          defaultMode: 0644
      - name: cargo-config
        configMap:
          name: nexus-proxy-config
          items:
          - key: cargo-config.toml
            path: cargo-config.toml
          defaultMode: 0644
---
# Service to expose Filebrowser
apiVersion: v1
kind: Service
metadata:
  name: claude-code
  namespace: claude-code
spec:
  selector:
    app: claude-code
  ports:
  - name: filebrowser
    port: 8090
    targetPort: 8090
  type: ClusterIP
---
# ConfigMap for Filebrowser settings
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebrowser-config
  namespace: claude-code
data:
  settings.json: |
    {
      "port": 8090,
      "baseURL": "",
      "address": "0.0.0.0",
      "log": "stdout",
      "database": "/database/filebrowser.db",
      "root": "/srv",
      "username": "admin",
      "password": "admin",
      "branding": {
        "name": "Claude Code Workspace",
        "disableExternal": false,
        "color": "#2979ff"
      },
      "authMethod": "password",
      "commands": {
        "after_save": [],
        "before_save": []
      },
      "shell": ["/bin/bash", "-c"],
      "allowEdit": true,
      "allowNew": true,
      "disablePreviewResize": false,
      "disableExec": false,
      "disableUsedPercentage": false,
      "hideDotfiles": false
    }
EOF
}

# Check if languages.conf exists
if [[ ! -f "$LANGUAGES_CONFIG" ]]; then
    echo -e "${RED}Error: $LANGUAGES_CONFIG not found${NC}"
    echo "Please ensure languages.conf is in the project directory"
    exit 1
fi

# Check if colima and kubernetes are running
if ! colima status &> /dev/null; then
    echo -e "${RED}Error: Colima is not running${NC}"
    echo "Please start Colima with: colima start --kubernetes"
    exit 1
fi

# Check if kubernetes is accessible
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Error: Kubernetes is not accessible${NC}"
    echo "Please make sure Colima started with --kubernetes flag"
    exit 1
fi

echo -e "${GREEN}Colima with Kubernetes is running and accessible${NC}"

# Check if Nexus is available
NEXUS_AVAILABLE=false
if check_nexus; then
    NEXUS_AVAILABLE=true
    # Set up Nexus build arguments
    export DOCKER_BUILDKIT=0
    export NEXUS_BUILD_ARGS="--build-arg PIP_INDEX_URL=http://host.lima.internal:8081/repository/pypi-proxy/simple/ --build-arg PIP_TRUSTED_HOST=host.lima.internal --build-arg NPM_REGISTRY=http://host.lima.internal:8081/repository/npm-proxy/ --build-arg GOPROXY=http://host.lima.internal:8081/repository/go-proxy/"
    echo -e "${GREEN}Nexus proxy will be used for package downloads${NC}"
else
    echo -e "${YELLOW}Nexus not detected, using default package repositories${NC}"
fi

# Clean up and redeploy if needed
if [ "$1" == "--clean" ] || [ "$1" == "-c" ]; then
    echo -e "${YELLOW}Cleaning up previous deployment...${NC}"
    kubectl delete deployment claude-code -n ${NAMESPACE} --ignore-not-found=true
    echo -e "${YELLOW}Removing previous Docker image...${NC}"
    docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
    echo -e "${YELLOW}Removing temporary build directory...${NC}"
    rm -rf "$TEMP_DIR"
fi

# Skip language selection if --no-select flag is provided
if [ "$1" != "--no-select" ] && [ "$2" != "--no-select" ]; then
    select_languages
fi

# Create custom Dockerfile
echo -e "${YELLOW}Creating custom Dockerfile...${NC}"
create_custom_dockerfile

# Build the Docker image
echo -e "${YELLOW}Building Docker image...${NC}"

# Check if Nexus build args are set
if [ -n "$NEXUS_BUILD_ARGS" ]; then
    echo -e "${GREEN}Using Nexus proxy for package downloads${NC}"
    docker build $NEXUS_BUILD_ARGS -t ${IMAGE_NAME}:${IMAGE_TAG} -f "$TEMP_DIR/Dockerfile" .
else
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f "$TEMP_DIR/Dockerfile" .
fi

# Load the image into colima's containerd
echo -e "${YELLOW}Loading image into Colima...${NC}"
docker save ${IMAGE_NAME}:${IMAGE_TAG} | colima ssh -- sudo ctr -n k8s.io images import -

# Create namespace if it doesn't exist
echo -e "${YELLOW}Creating Kubernetes namespace...${NC}"
kubectl apply -f kubernetes/namespace.yaml

# Apply Kubernetes resources
echo -e "${YELLOW}Applying Kubernetes resources...${NC}"
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/pvc.yaml

# Apply deployment based on Nexus availability
if [ "$NEXUS_AVAILABLE" = true ]; then
    create_deployment_with_nexus
    kubectl apply -f "$TEMP_DIR/deployment.yaml"
else
    kubectl apply -f kubernetes/deployment.yaml
fi

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/claude-code -n ${NAMESPACE}

# Get pod name
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=claude-code -o jsonpath="{.items[0].metadata.name}")

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "Claude Code is now running in container: ${YELLOW}${POD_NAME}${NC}"

if [ "$NEXUS_AVAILABLE" = true ]; then
    echo -e "${GREEN}✓ Container is configured to use Nexus proxy${NC}"
fi

echo -e "\n${BLUE}File Manager Access:${NC}"
echo -e "A web-based file manager (Filebrowser) is included for easy file uploads/downloads."
echo -e "To access it, run:"
echo -e "${YELLOW}kubectl port-forward -n ${NAMESPACE} service/claude-code 8090:8090${NC}"
echo -e "Then open: ${BLUE}http://localhost:8090${NC}"
echo -e "Default credentials: ${YELLOW}admin / admin${NC} (change after first login!)"

echo -e "\n${BLUE}Claude Code Access:${NC}"
echo -e "To connect to the container, run:"
echo -e "${YELLOW}kubectl exec -it -n ${NAMESPACE} ${POD_NAME} -- su - claude${NC}"
echo -e "\nOnce connected, you can start Claude Code with:"
echo -e "${YELLOW}cd workspace${NC}"
echo -e "${YELLOW}claude${NC}"

# Clean up temp directory
echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"
