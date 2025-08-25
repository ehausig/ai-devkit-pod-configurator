#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_DIR="$HOME/.ai-devkit"
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

echo -e "${BLUE}=== AI DevKit - Container Runtime Configuration ===${NC}"
echo ""

# ============================================================================
# TEST CONTAINER COMMANDS
# ============================================================================

test_build_command() {
    local cmd="$1"
    local test_dir=$(mktemp -d)
    
    # Create minimal Dockerfile for testing
    cat > "$test_dir/Dockerfile" << 'EOF'
FROM alpine:latest
RUN echo "test"
EOF
    
    cd "$test_dir"
    
    # Test the build command
    if $cmd build -t test:ai-devkit-test . &>/dev/null; then
        # Clean up test image
        $cmd rmi test:ai-devkit-test &>/dev/null || true
        cd - > /dev/null
        rm -rf "$test_dir"
        return 0
    else
        cd - > /dev/null
        rm -rf "$test_dir"
        return 1
    fi
}

# ============================================================================
# DETECT AND TEST COMMANDS
# ============================================================================

detect_working_commands() {
    local commands=()
    
    echo "Testing container build tools..."
    echo ""
    
    # Test Docker variations
    if command -v docker &> /dev/null; then
        echo -n "  Testing 'docker'... "
        if test_build_command "docker"; then
            echo -e "${GREEN}✓ Works${NC}"
            commands+=("docker|Docker (rootless or with permissions)")
        else
            echo -e "${YELLOW}✗ Fails${NC}"
            
            echo -n "  Testing 'sudo docker'... "
            if test_build_command "sudo docker"; then
                echo -e "${GREEN}✓ Works${NC}"
                commands+=("sudo docker|Docker (requires sudo)")
            else
                echo -e "${RED}✗ Fails${NC}"
            fi
        fi
    fi
    
    # Test nerdctl variations
    if command -v nerdctl &> /dev/null; then
        echo -n "  Testing 'nerdctl'... "
        if test_build_command "nerdctl"; then
            echo -e "${GREEN}✓ Works${NC}"
            commands+=("nerdctl|nerdctl (rootless mode)")
        else
            echo -e "${YELLOW}✗ Fails${NC}"
            
            # Try with sudo
            echo -n "  Testing 'sudo nerdctl'... "
            if test_build_command "sudo nerdctl"; then
                echo -e "${GREEN}✓ Works${NC}"
                commands+=("sudo nerdctl|nerdctl with sudo")
            else
                echo -e "${YELLOW}✗ Fails${NC}"
            fi
            
            # Try with K3s socket
            if [ -S "/run/k3s/containerd/containerd.sock" ]; then
                echo -n "  Testing 'sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io'... "
                if test_build_command "sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io"; then
                    echo -e "${GREEN}✓ Works${NC}"
                    commands+=("sudo nerdctl --address /run/k3s/containerd/containerd.sock --namespace k8s.io|nerdctl with K3s containerd")
                else
                    echo -e "${RED}✗ Fails${NC}"
                fi
            fi
        fi
    fi
    
    # Test Podman
    if command -v podman &> /dev/null; then
        echo -n "  Testing 'podman'... "
        if test_build_command "podman"; then
            echo -e "${GREEN}✓ Works${NC}"
            commands+=("podman|Podman (rootless containers)")
        else
            echo -e "${YELLOW}✗ Fails${NC}"
            
            echo -n "  Testing 'sudo podman'... "
            if test_build_command "sudo podman"; then
                echo -e "${GREEN}✓ Works${NC}"
                commands+=("sudo podman|Podman (requires sudo)")
            else
                echo -e "${RED}✗ Fails${NC}"
            fi
        fi
    fi
    
    if [ ${#commands[@]} -eq 0 ]; then
        echo ""
        echo -e "${RED}No working container build tools found!${NC}"
        echo "Please install docker, nerdctl, or podman."
        exit 1
    fi
    
    echo ""
    echo "${commands[@]}"
}

# ============================================================================
# DETECT KUBERNETES RUNTIME
# ============================================================================

detect_kubernetes_runtime() {
    # Check for K3s
    if command -v k3s &> /dev/null || sudo systemctl is-active --quiet k3s 2>/dev/null; then
        echo "k3s"
        return 0
    fi
    
    # Check for Colima
    if command -v colima &> /dev/null && colima status &> /dev/null 2>&1; then
        echo "colima"
        return 0
    fi
    
    # Check for Docker Desktop
    if [[ -f "$HOME/.docker/config.json" ]] && grep -q "desktop" "$HOME/.docker/config.json" 2>/dev/null; then
        echo "docker-desktop"
        return 0
    fi
    
    # Check for minikube
    if command -v minikube &> /dev/null && minikube status &> /dev/null 2>&1; then
        echo "minikube"
        return 0
    fi
    
    # Check for kind
    if command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q .; then
        echo "kind"
        return 0
    fi
    
    echo "unknown"
}

# ============================================================================
# GET IMPORT METHOD
# ============================================================================

get_import_method() {
    local build_cmd="$1"
    local runtime="$2"
    
    # If using nerdctl with K3s socket directly, it's direct import
    if [[ "$build_cmd" == *"/run/k3s/containerd/containerd.sock"* ]] && [[ "$runtime" == "k3s" ]]; then
        echo "direct"
    # If using docker with Docker Desktop
    elif [[ "$build_cmd" == *"docker"* ]] && [[ "$runtime" == "docker-desktop" ]]; then
        echo "none"
    # Default to save-load for safety
    else
        echo "save-load"
    fi
}

# ============================================================================
# USER SELECTION
# ============================================================================

select_build_command() {
    local commands_string="$1"
    
    # Parse commands into arrays
    local commands=()
    local descriptions=()
    
    IFS=' ' read -ra items <<< "$commands_string"
    for item in "${items[@]}"; do
        IFS='|' read -r cmd desc <<< "$item"
        commands+=("$cmd")
        descriptions+=("$desc")
    done
    
    # Display menu to stderr so it shows to user (stdout is captured for return value)
    echo "Available container build commands:" >&2
    echo "" >&2
    
    for i in "${!commands[@]}"; do
        echo "  $((i+1))) ${commands[$i]}" >&2
        echo "     ${descriptions[$i]}" >&2
    done
    
    echo "" >&2
    
    if [ ${#commands[@]} -eq 1 ]; then
        echo "Only one working command found, using it automatically." >&2
        echo "${commands[0]}"
        return 0
    fi
    
    read -p "Select build command (1-${#commands[@]}): " selection
    
    if [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#commands[@]}" ]]; then
        echo "${commands[$((selection-1))]}"
    else
        echo "Invalid selection" >&2
        exit 1
    fi
}

# ============================================================================
# MAIN FLOW
# ============================================================================

main() {
    # Check if configuration already exists
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}Existing configuration found:${NC}"
        echo ""
        cat "$CONFIG_FILE" | grep -E "build_command:|build_tool:|runtime:|runtime_import:" | sed 's/^/  /'
        echo ""
        read -p "Do you want to reconfigure? (y/N): " reconfigure
        if [[ "$reconfigure" != "y" ]] && [[ "$reconfigure" != "Y" ]]; then
            echo "Keeping existing configuration."
            exit 0
        fi
        echo ""
    fi
    
    # Detect working commands
    working_commands=$(detect_working_commands)
    
    # Let user select
    selected_command=$(select_build_command "$working_commands")
    
    echo ""
    echo "Selected: $selected_command"
    echo ""
    
    # Detect Kubernetes runtime
    echo "Detecting Kubernetes runtime..."
    runtime=$(detect_kubernetes_runtime)
    echo -e "${GREEN}✓${NC} Detected: $runtime"
    echo ""
    
    # Determine import method
    import_method=$(get_import_method "$selected_command" "$runtime")
    
    # Write configuration
    cat > "$CONFIG_FILE" << EOF
# AI DevKit Container Runtime Configuration
# Generated: $(date)
# To reconfigure: ./configure-container-runtime.sh

container:
  # The full command to build containers
  build_command: "$selected_command"
  
  # Kubernetes runtime
  runtime: $runtime
  
  # How to import images to runtime
  runtime_import: $import_method
EOF
    
    echo -e "${GREEN}✓${NC} Configuration saved to $CONFIG_FILE"
    echo ""
    echo "Summary:"
    echo "  • Build command: $selected_command"
    echo "  • Runtime: $runtime"
    echo "  • Import method: $import_method"
    echo ""
    echo "You can now run ./build-and-deploy.sh"
}

# Run main function
main "$@"