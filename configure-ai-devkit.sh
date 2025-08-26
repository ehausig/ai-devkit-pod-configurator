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

echo -e "${BLUE}=== AI DevKit Configuration ===${NC}"
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
        # Check if K3s socket exists first
        if [ -S "/run/k3s/containerd/containerd.sock" ]; then
            # K3s is present, use K3s configuration
            if sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io version &> /dev/null 2>&1; then
                echo "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
                return
            elif nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io version &> /dev/null 2>&1; then
                echo "nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"
                return
            fi
            # K3s socket exists but nerdctl can't connect - fall through to standard detection
        fi
        
        # Check standard nerdctl
        if nerdctl version &> /dev/null 2>&1; then
            echo "nerdctl"
        elif sudo nerdctl version &> /dev/null 2>&1; then
            echo "sudo nerdctl"
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

detect_nexus() {
    local urls=()
    local descriptions=()
    
    # Check common Nexus URLs based on detected runtime
    local runtime=$(detect_kubernetes_runtime)
    
    # Always check localhost first
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/service/rest/v1/status 2>/dev/null | grep -q "200\|401"; then
        urls+=("http://localhost:8081")
        descriptions+=("Nexus on localhost:8081")
    fi
    
    # Check runtime-specific URLs
    case "$runtime" in
        "colima"|"lima")
            if curl -s -o /dev/null -w "%{http_code}" http://host.lima.internal:8081/service/rest/v1/status 2>/dev/null | grep -q "200\|401"; then
                urls+=("http://host.lima.internal:8081")
                descriptions+=("Nexus via Lima host (host.lima.internal:8081)")
            fi
            ;;
        "docker-desktop")
            if curl -s -o /dev/null -w "%{http_code}" http://host.docker.internal:8081/service/rest/v1/status 2>/dev/null | grep -q "200\|401"; then
                urls+=("http://host.docker.internal:8081")
                descriptions+=("Nexus via Docker Desktop (host.docker.internal:8081)")
            fi
            ;;
        "k3s"|"minikube"|"kind")
            # For K3s/Linux, check docker bridge IP
            if ip route | grep -q "docker0"; then
                local docker_bridge=$(ip route | grep "docker0" | awk '{print $9}' | head -1)
                if [[ -n "$docker_bridge" ]] && curl -s -o /dev/null -w "%{http_code}" http://${docker_bridge}:8081/service/rest/v1/status 2>/dev/null | grep -q "200\|401"; then
                    urls+=("http://${docker_bridge}:8081")
                    descriptions+=("Nexus via Docker bridge (${docker_bridge}:8081)")
                fi
            fi
            
            # Check default bridge IP
            if curl -s -o /dev/null -w "%{http_code}" http://172.17.0.1:8081/service/rest/v1/status 2>/dev/null | grep -q "200\|401"; then
                urls+=("http://172.17.0.1:8081")
                descriptions+=("Nexus via default Docker bridge (172.17.0.1:8081)")
            fi
            ;;
    esac
    
    # Return arrays as string (with record separator)
    if [ ${#urls[@]} -gt 0 ]; then
        printf "%s\x1e%s\n" "${urls[@]}" "${descriptions[@]}"
    fi
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
        echo -e "  ${BOLD}$((i+1))${NC}) ${descriptions[$i]}"
        echo -e "     Command: ${CYAN}${options[$i]}${NC}"
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

# ============================================================================
# NEXUS CONFIGURATION
# ============================================================================

echo ""
echo "Detecting Nexus repository manager..."
echo ""

nexus_enabled="false"
nexus_url=""

# Detect available Nexus instances
nexus_detection=$(detect_nexus)
if [[ -n "$nexus_detection" ]]; then
    # Parse detection results
    IFS=$'\x1e' read -ra nexus_data <<< "$nexus_detection"
    nexus_urls=()
    nexus_descs=()
    
    # Split into urls and descriptions
    half=$((${#nexus_data[@]} / 2))
    for ((i=0; i<$half; i++)); do
        nexus_urls+=("${nexus_data[$i]}")
        nexus_descs+=("${nexus_data[$((i + half))]}")
    done
    
    echo -e "${GREEN}✓${NC} Found Nexus repository manager:"
    echo ""
    
    if [ ${#nexus_urls[@]} -eq 1 ]; then
        echo -e "  Using: ${CYAN}${nexus_descs[0]}${NC}"
        nexus_url="${nexus_urls[0]}"
        nexus_enabled="true"
    else
        echo "Multiple Nexus endpoints detected:"
        echo ""
        for i in "${!nexus_urls[@]}"; do
            echo -e "  ${BOLD}$((i+1))${NC}) ${nexus_descs[$i]}"
            echo -e "     URL: ${CYAN}${nexus_urls[$i]}${NC}"
            echo ""
        done
        echo -e "  ${BOLD}$((${#nexus_urls[@]}+1))${NC}) None - Don't use Nexus proxy"
        echo -e "  ${BOLD}$((${#nexus_urls[@]}+2))${NC}) Custom - Enter a different URL"
        echo ""
        
        while true; do
            read -p "Select Nexus configuration (1-$((${#nexus_urls[@]}+2))): " nexus_selection
            if [[ "$nexus_selection" =~ ^[0-9]+$ ]]; then
                if [ "$nexus_selection" -ge 1 ] && [ "$nexus_selection" -le "${#nexus_urls[@]}" ]; then
                    nexus_url="${nexus_urls[$((nexus_selection - 1))]}"
                    nexus_enabled="true"
                    break
                elif [ "$nexus_selection" -eq "$((${#nexus_urls[@]}+1))" ]; then
                    nexus_enabled="false"
                    break
                elif [ "$nexus_selection" -eq "$((${#nexus_urls[@]}+2))" ]; then
                    read -p "Enter custom Nexus URL (e.g., http://nexus.example.com:8081): " custom_url
                    if [[ "$custom_url" =~ ^https?:// ]]; then
                        nexus_url="$custom_url"
                        nexus_enabled="true"
                        break
                    else
                        echo -e "${RED}Invalid URL. Must start with http:// or https://${NC}"
                    fi
                else
                    echo -e "${RED}Invalid selection.${NC}"
                fi
            else
                echo -e "${RED}Please enter a number.${NC}"
            fi
        done
    fi
else
    echo -e "${YELLOW}No Nexus repository manager detected.${NC}"
    echo ""
    read -p "Do you want to configure a Nexus proxy manually? (y/N): " configure_nexus
    if [[ "$configure_nexus" =~ ^[Yy] ]]; then
        read -p "Enter Nexus URL (e.g., http://nexus.example.com:8081): " custom_url
        if [[ "$custom_url" =~ ^https?:// ]]; then
            nexus_url="$custom_url"
            nexus_enabled="true"
        fi
    fi
fi

# Write configuration
cat > "$CONFIG_FILE" << EOF
# AI DevKit Configuration
# Generated: $(date)
# To reconfigure: ./configure-ai-devkit.sh

container:
  # The command to build containers
  build_command: "$selected_command"
  
  # Kubernetes runtime
  runtime: $runtime
  
  # How to import images to runtime
  runtime_import: $import_method

nexus:
  # Whether to use Nexus proxy
  enabled: $nexus_enabled
  
  # Nexus URL (if enabled)
  url: "$nexus_url"
  
  # Repository types to proxy (can be customized)
  repositories:
    apt: true
    pypi: true
    npm: true
    go: true
EOF

echo -e "${GREEN}✓${NC} Configuration saved to $CONFIG_FILE"
echo ""
echo "Summary:"
echo "  • Build tool: $selected_description"
echo "  • Command: $selected_command"
echo "  • Runtime: $runtime"
echo "  • Import method: $import_method"
if [[ "$nexus_enabled" == "true" ]]; then
    echo "  • Nexus proxy: $nexus_url"
else
    echo "  • Nexus proxy: disabled"
fi
echo ""
echo -e "You can now run: ${BOLD}./build-and-deploy.sh${NC}"