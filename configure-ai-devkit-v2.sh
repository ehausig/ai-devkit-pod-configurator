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

# Repository TUI will be implemented here
# For now, placeholder that saves minimal config

configure_repositories() {
    echo ""
    read -p "Configure repositories? [y/N]: " answer
    
    if [[ ! "$answer" =~ ^[Yy] ]]; then
        return
    fi
    
    # This will be replaced with professional TUI
    echo ""
    echo "Repository configuration coming soon..."
    echo "(Currently in development)"
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