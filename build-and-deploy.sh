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
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f "$TEMP_DIR/Dockerfile" .

# Load the image into colima's containerd
echo -e "${YELLOW}Loading image into Colima...${NC}"
colima kubernetes load ${IMAGE_NAME}:${IMAGE_TAG}

# Create namespace if it doesn't exist
echo -e "${YELLOW}Creating Kubernetes namespace...${NC}"
kubectl apply -f kubernetes/namespace.yaml

# Apply Kubernetes resources
echo -e "${YELLOW}Applying Kubernetes resources...${NC}"
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/pvc.yaml
kubectl apply -f kubernetes/deployment.yaml

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
kubectl wait --for=condition=available --timeout=120s deployment/claude-code -n ${NAMESPACE}

# Get pod name
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=claude-code -o jsonpath="{.items[0].metadata.name}")

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "Claude Code is now running in container: ${YELLOW}${POD_NAME}${NC}"
echo -e "\nTo connect to the container, run:"
echo -e "${YELLOW}kubectl exec -it -n ${NAMESPACE} ${POD_NAME} -- bash${NC}"
echo -e "\nOnce connected, you can start Claude Code with:"
echo -e "${YELLOW}cd /home/claude/workspace${NC}"
echo -e "${YELLOW}claude${NC}"

# Clean up temp directory
echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "$TEMP_DIR"
