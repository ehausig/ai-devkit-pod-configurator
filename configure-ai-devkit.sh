#!/bin/bash

# AI DevKit Configuration Script v2
# Professional, minimal, production-ready

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly VERSION="2.0.0"
readonly CONFIG_DIR="$HOME/.ai-devkit"
readonly CONFIG_FILE="$CONFIG_DIR/config.yaml"
readonly NEXUS_CACHE="$CONFIG_DIR/nexus-cache.yaml"

# Colors (minimal use)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ============================================================================
# DEPENDENCIES
# ============================================================================

# Source repository configuration library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/repository-config.sh" 2>/dev/null || {
    echo "Error: Cannot load repository configuration library"
    exit 1
}

# ============================================================================
# CONTAINER RUNTIME DETECTION
# ============================================================================

detect_container_tools() {
    local tools=()
    
    # Check for Docker
    if command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1; then
        tools+=("docker:Docker:docker")
    fi
    
    # Check for nerdctl
    if command -v nerdctl >/dev/null 2>&1; then
        # Check if it's k3s nerdctl
        if [[ -S "/run/k3s/containerd/containerd.sock" ]]; then
            tools+=("nerdctl-k3s:nerdctl (k3s):sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io")
        else
            tools+=("nerdctl:nerdctl:nerdctl")
        fi
    fi
    
    # Check for Podman
    if command -v podman >/dev/null 2>&1 && podman version >/dev/null 2>&1; then
        tools+=("podman:Podman:podman")
    fi
    
    printf '%s\n' "${tools[@]}"
}

detect_kubernetes_runtime() {
    # Check for various Kubernetes distributions
    if [[ -S "/run/k3s/containerd/containerd.sock" ]]; then
        echo "k3s"
    elif command -v minikube >/dev/null 2>&1 && minikube status >/dev/null 2>&1; then
        echo "minikube"
    elif [[ -S "/var/run/docker.sock" ]] && docker info 2>/dev/null | grep -q "Kubernetes"; then
        echo "docker-desktop"
    elif command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -q .; then
        echo "kind"
    elif systemctl is-active --quiet k3s || systemctl is-active --quiet k3s-agent; then
        echo "k3s"
    else
        echo "unknown"
    fi
}

# ============================================================================
# PHASE 1: CONTAINER RUNTIME CONFIGURATION
# ============================================================================

configure_container_runtime() {
    local tools=($(detect_container_tools))
    
    if [[ ${#tools[@]} -eq 0 ]]; then
        echo -e "${RED}No container tools found${NC}"
        echo "Please install Docker, Podman, or nerdctl"
        exit 1
    fi
    
    local runtime=$(detect_kubernetes_runtime)
    
    # Header
    clear
    printf "╔%72s╗\n" | tr ' ' '═'
    printf "║%26s AI DevKit Configuration v${VERSION} %26s║\n" "" ""
    printf "╚%72s╝\n\n" | tr ' ' '═'
    
    echo "Detecting container environment..."
    
    # Show detected tools concisely
    printf "  ${GREEN}✓${NC} Found: "
    for tool in "${tools[@]}"; do
        IFS=':' read -r id name cmd <<< "$tool"
        printf "$name "
    done
    echo ""
    
    [[ "$runtime" != "unknown" ]] && echo -e "  ${GREEN}✓${NC} Runtime: $runtime"
    echo ""
    
    # Single selection if only one tool
    local selected_tool selected_cmd
    if [[ ${#tools[@]} -eq 1 ]]; then
        IFS=':' read -r id name cmd <<< "${tools[0]}"
        selected_tool="$name"
        selected_cmd="$cmd"
        echo "Using $selected_tool"
    else
        # Simple selection menu
        echo "Select build tool:"
        local i=1
        for tool in "${tools[@]}"; do
            IFS=':' read -r id name cmd <<< "$tool"
            if [[ $i -eq 1 ]]; then
                printf "  ${CYAN}→${NC} %s\n" "$name"
            else
                printf "    %s\n" "$name"
            fi
            ((i++))
        done
        
        echo ""
        read -p "Choice (1-${#tools[@]}): " choice
        
        if [[ $choice -ge 1 ]] && [[ $choice -le ${#tools[@]} ]]; then
            IFS=':' read -r id name cmd <<< "${tools[$((choice-1))]}"
            selected_tool="$name"
            selected_cmd="$cmd"
        else
            echo -e "${RED}Invalid selection${NC}"
            exit 1
        fi
    fi
    
    # Determine import method
    local import_method="direct"
    if [[ "$runtime" == "minikube" ]]; then
        import_method="minikube"
    elif [[ "$runtime" == "kind" ]]; then
        import_method="kind"
    fi
    
    # Save container configuration
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# AI DevKit Configuration
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

container:
  build_command: "$selected_cmd"
  runtime: "$runtime"
  runtime_import: "$import_method"
EOF
    
    echo ""
    echo -e "${GREEN}✓${NC} Container runtime configured"
}

# ============================================================================
# PHASE 2: REPOSITORY CONFIGURATION
# ============================================================================

# Global variables for repository configuration
declare -A comp_configs
NEXUS_URL=""
NEXUS_AUTH_TYPE="anonymous"
NEXUS_USERNAME=""
NEXUS_PASSWORD=""

configure_repositories() {
    echo ""
    read -p "Configure repositories? [y/N]: " answer
    
    if [[ ! "$answer" =~ ^[Yy] ]]; then
        return
    fi
    
    # Get eligible components
    local components=()
    while IFS= read -r comp; do
        components+=("$comp")
    done < <(find_eligible_components 2>/dev/null)
    
    if [[ ${#components[@]} -eq 0 ]]; then
        echo "No components with repository support found"
        return
    fi
    
    # Parse components
    local comp_ids=() comp_names=() comp_formats=()
    for comp in "${components[@]}"; do
        IFS=':' read -r id name format _ <<< "$comp"
        comp_ids+=("$id")
        comp_names+=("$name")
        comp_formats+=("$format")
    done
    
    # Repository configuration menu
    while true; do
        clear
        printf "╔%72s╗\n" | tr ' ' '═'
        printf "║%25s Repository Configuration %26s║\n" "" ""
        printf "╚%72s╝\n\n" | tr ' ' '═'
        
        # Display components with status
        local configured=0
        for i in "${!comp_ids[@]}"; do
            local status="○"
            if [[ -n "${comp_configs[${comp_ids[$i]}]}" ]]; then
                status="${GREEN}✓${NC}"
                ((configured++))
            fi
            printf "  %b %-40s %10s\n" "$status" "${comp_names[$i]:0:40}" "(${comp_formats[$i]})"
        done
        
        echo ""
        echo "─────────────────────────────────────────────────────────────────────────"
        printf "  %d/%d configured" $configured ${#comp_ids[@]}
        [[ -n "$NEXUS_URL" ]] && printf "    Nexus: %s" "$NEXUS_URL"
        echo -e "\n"
        
        echo "Options:"
        echo "  [1-${#comp_ids[@]}] Configure component"
        [[ -z "$NEXUS_URL" ]] && echo "  [n] Configure Nexus"
        echo "  [s] Save and exit"
        echo "  [q] Quit without saving"
        echo ""
        
        read -rsn1 -p "Select: " key
        echo ""
        
        case "$key" in
            [1-9])
                if [[ $key -le ${#comp_ids[@]} ]]; then
                    configure_single_component $((key-1)) "${comp_ids[$((key-1))]}" "${comp_names[$((key-1))]}" "${comp_formats[$((key-1))]}"
                fi
                ;;
            n|N)
                [[ -z "$NEXUS_URL" ]] && configure_nexus
                ;;
            s|S)
                save_repository_configuration
                break
                ;;
            q|Q)
                break
                ;;
        esac
    done
}

configure_single_component() {
    local idx=$1
    local id=$2
    local name=$3
    local format=$4
    
    clear
    echo "Configure: $name"
    echo "Format: $format"
    echo ""
    
    local current="${comp_configs[$id]}"
    [[ -n "$current" ]] && echo "Current: $current" && echo ""
    
    echo "[1] Use default (no configuration)"
    [[ -n "$NEXUS_URL" ]] && echo "[2] Use Nexus repository"
    echo "[3] Custom repository URL"
    echo "[4] Clear configuration"
    echo "[5] Back"
    echo ""
    
    read -rsn1 -p "Select: " choice
    echo ""
    
    case "$choice" in
        1)
            comp_configs["$id"]="default"
            echo -e "${GREEN}✓${NC} Will use default repository"
            sleep 0.5
            ;;
        2)
            if [[ -n "$NEXUS_URL" ]]; then
                comp_configs["$id"]="nexus:${format}-proxy"
                echo -e "${GREEN}✓${NC} Will use Nexus repository"
                sleep 0.5
            fi
            ;;
        3)
            read -p "Repository URL: " url
            if [[ -n "$url" ]]; then
                comp_configs["$id"]="custom:$url"
                echo -e "${GREEN}✓${NC} Custom repository configured"
                sleep 0.5
            fi
            ;;
        4)
            unset comp_configs["$id"]
            echo "Configuration cleared"
            sleep 0.5
            ;;
    esac
}

configure_nexus() {
    clear
    echo "Nexus Repository Manager Configuration"
    echo ""
    read -p "Nexus URL [http://localhost:8081]: " url
    NEXUS_URL="${url:-http://localhost:8081}"
    NEXUS_URL="${NEXUS_URL%/}"  # Remove trailing slash
    
    echo ""
    echo "[1] Anonymous access"
    echo "[2] Basic authentication"
    read -rsn1 -p "Select: " auth
    echo ""
    
    if [[ "$auth" == "2" ]]; then
        NEXUS_AUTH_TYPE="basic"
        read -p "Username: " NEXUS_USERNAME
        read -sp "Password: " NEXUS_PASSWORD
        echo ""
    fi
    
    echo -e "${GREEN}✓${NC} Nexus configured"
    sleep 1
}

save_repository_configuration() {
    echo "Saving configuration..."
    
    # Append Nexus configuration if configured
    if [[ -n "$NEXUS_URL" ]]; then
        cat >> "$CONFIG_FILE" << EOF

nexus:
  enabled: true
  url: "$NEXUS_URL"
  auth:
    type: "$NEXUS_AUTH_TYPE"
EOF
        if [[ "$NEXUS_AUTH_TYPE" == "basic" ]]; then
            cat >> "$CONFIG_FILE" << EOF
    username: "$NEXUS_USERNAME"
    password: "encrypted:$(echo -n "$NEXUS_PASSWORD" | base64)"
EOF
        fi
    fi
    
    # Append component repositories if any configured
    if [[ ${#comp_configs[@]} -gt 0 ]]; then
        echo "" >> "$CONFIG_FILE"
        echo "component_repos:" >> "$CONFIG_FILE"
        
        for id in "${!comp_configs[@]}"; do
            local config="${comp_configs[$id]}"
            
            if [[ "$config" == "nexus:"* ]]; then
                local repo_name="${config#nexus:}"
                cat >> "$CONFIG_FILE" << EOF
  $id:
    - name: "$repo_name"
      url: "${NEXUS_URL}/repository/$repo_name"
      type: "local_readonly"
      auth: "inherit"
      primary: true
EOF
            elif [[ "$config" == "custom:"* ]]; then
                local url="${config#custom:}"
                cat >> "$CONFIG_FILE" << EOF
  $id:
    - name: "custom"
      url: "$url"
      type: "remote"
      auth: "anonymous"
      primary: true
EOF
            fi
            # "default" entries are not written - component will use defaults
        done
    fi
    
    echo -e "${GREEN}✓${NC} Configuration saved"
    sleep 0.5
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Ensure config directory exists
    mkdir -p "$CONFIG_DIR"
    
    # Phase 1: Container runtime
    configure_container_runtime
    
    # Phase 2: Repositories (optional)
    configure_repositories
    
    # Summary
    echo ""
    printf "╔%72s╗\n" | tr ' ' '═'
    printf "║%30s Configuration Complete %31s║\n" "" ""
    printf "╚%72s╝\n" | tr ' ' '═'
    echo ""
    echo "Run ${BOLD}./build-and-deploy.sh${NC} to build and deploy components"
    echo ""
}

# Run main function
main "$@"