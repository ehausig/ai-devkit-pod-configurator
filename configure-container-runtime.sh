#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

CONFIG_DIR="$HOME/.ai-devkit"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

echo -e "${BLUE}=== AI DevKit - Container Runtime Configuration ===${NC}"
echo ""

# ============================================================================
# DETECTION FUNCTIONS
# ============================================================================

detect_docker() {
    if command -v docker &> /dev/null; then
        # Check if docker works without sudo
        if docker version &> /dev/null 2>&1; then
            echo "docker"
        elif sudo docker version &> /dev/null 2>&1; then
            echo "sudo docker"
        fi
    fi
}

detect_nerdctl() {
    if command -v nerdctl &> /dev/null; then
        # Check if nerdctl works without sudo
        if nerdctl version &> /dev/null 2>&1; then
            echo "nerdctl"
        elif sudo nerdctl version &> /dev/null 2>&1; then
            # Check if it's using K3s containerd
            if [ -S "/run/k3s/containerd/containerd.sock" ]; then
                echo "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
            else
                echo "sudo nerdctl"
            fi
        fi
    fi
}

detect_podman() {
    if command -v podman &> /dev/null; then
        # Check if podman works
        if podman version &> /dev/null 2>&1; then
            echo "podman"
        elif sudo podman version &> /dev/null 2>&1; then
            echo "sudo podman"
        fi
    fi
}

detect_kubernetes_runtime() {
    # Check for K3s
    if command -v k3s &> /dev/null || [ -S "/run/k3s/containerd/containerd.sock" ]; then
        echo "k3s"
        return
    fi
    
    # Check for Colima
    if command -v colima &> /dev/null && colima status &> /dev/null 2>&1; then
        echo "colima"
        return
    fi
    
    # Check for Docker Desktop
    if [[ -f "$HOME/.docker/config.json" ]] && grep -q "desktop" "$HOME/.docker/config.json" 2>/dev/null; then
        echo "docker-desktop"
        return
    fi
    
    # Check for minikube
    if command -v minikube &> /dev/null && minikube status &> /dev/null 2>&1; then
        echo "minikube"
        return
    fi
    
    # Check for kind
    if command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q .; then
        echo "kind"
        return
    fi
    
    echo "unknown"
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

# Detect available container tools
echo "Detecting container tools..."
echo ""

options=()
descriptions=()

# Check for Docker
docker_cmd=$(detect_docker)
if [[ -n "$docker_cmd" ]]; then
    options+=("$docker_cmd")
    if [[ "$docker_cmd" == "sudo docker" ]]; then
        descriptions+=("Docker (requires sudo)")
    else
        descriptions+=("Docker")
    fi
    echo -e "  ${GREEN}✓${NC} Found Docker"
fi

# Check for nerdctl
nerdctl_cmd=$(detect_nerdctl)
if [[ -n "$nerdctl_cmd" ]]; then
    options+=("$nerdctl_cmd")
    if [[ "$nerdctl_cmd" == *"k3s"* ]]; then
        descriptions+=("nerdctl with K3s containerd")
    elif [[ "$nerdctl_cmd" == "sudo nerdctl" ]]; then
        descriptions+=("nerdctl (requires sudo)")
    else
        descriptions+=("nerdctl")
    fi
    echo -e "  ${GREEN}✓${NC} Found nerdctl"
fi

# Check for Podman
podman_cmd=$(detect_podman)
if [[ -n "$podman_cmd" ]]; then
    options+=("$podman_cmd")
    if [[ "$podman_cmd" == "sudo podman" ]]; then
        descriptions+=("Podman (requires sudo)")
    else
        descriptions+=("Podman")
    fi
    echo -e "  ${GREEN}✓${NC} Found Podman"
fi

if [ ${#options[@]} -eq 0 ]; then
    echo ""
    echo -e "${RED}Error: No container build tools found!${NC}"
    echo ""
    echo "Please install one of the following:"
    echo "  • Docker: https://docs.docker.com/get-docker/"
    echo "  • nerdctl: https://github.com/containerd/nerdctl"
    echo "  • Podman: https://podman.io/getting-started/installation"
    exit 1
fi

echo ""

# Detect Kubernetes runtime
echo "Detecting Kubernetes runtime..."
runtime=$(detect_kubernetes_runtime)
echo -e "  ${GREEN}✓${NC} Detected: $runtime"
echo ""

# Show menu if multiple options
if [ ${#options[@]} -eq 1 ]; then
    echo "Found one container tool:"
    echo -e "  ${CYAN}${options[0]}${NC} - ${descriptions[0]}"
    echo ""
    selected_index=0
else
    echo "Available container build tools:"
    echo ""
    for i in "${!options[@]}"; do
        echo -e "  ${BOLD}$((i+1))${NC}) ${CYAN}${options[$i]}${NC}"
        echo "     ${descriptions[$i]}"
        echo ""
    done
    
    while true; do
        read -p "Select container build tool (1-${#options[@]}): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#options[@]}" ]; then
            selected_index=$((selection - 1))
            break
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and ${#options[@]}.${NC}"
        fi
    done
fi

selected_command="${options[$selected_index]}"
selected_description="${descriptions[$selected_index]}"

echo ""
echo -e "Selected: ${CYAN}$selected_command${NC}"
echo ""

# Determine import method based on tool and runtime
import_method="save-load"
if [[ "$selected_command" == *"k3s"* ]] && [[ "$runtime" == "k3s" ]]; then
    import_method="direct"
elif [[ "$selected_command" == *"docker"* ]] && [[ "$runtime" == "docker-desktop" ]]; then
    import_method="none"
fi

# Write configuration
cat > "$CONFIG_FILE" << EOF
# AI DevKit Container Runtime Configuration
# Generated: $(date)
# To reconfigure: ./configure-container-runtime.sh

container:
  # The command to build containers
  build_command: "$selected_command"
  
  # Kubernetes runtime
  runtime: $runtime
  
  # How to import images to runtime
  runtime_import: $import_method
EOF

echo -e "${GREEN}✓${NC} Configuration saved to $CONFIG_FILE"
echo ""
echo "Summary:"
echo "  • Build tool: $selected_description"
echo "  • Command: $selected_command"
echo "  • Runtime: $runtime"
echo "  • Import method: $import_method"
echo ""
echo "You can now run: ${BOLD}./build-and-deploy.sh${NC}"