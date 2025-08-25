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

echo -e "${BOLD}${CYAN}AI DevKit Container Runtime Configuration${NC}"
echo "=========================================="
echo ""

# ============================================================================
# DETECTION FUNCTIONS
# ============================================================================

detect_container_tools() {
    local tools=()
    
    # Check for docker (and if it's really nerdctl)
    if command -v docker &> /dev/null; then
        if [[ -L "$(which docker)" ]] && readlink "$(which docker)" | grep -q nerdctl; then
            tools+=("nerdctl (via docker alias)")
        elif docker version &> /dev/null 2>&1; then
            local version_output=$(docker version 2>&1)
            if echo "$version_output" | grep -q "nerdctl"; then
                tools+=("nerdctl (via docker alias)")
            else
                tools+=("docker")
            fi
        fi
    fi
    
    # Check for standalone nerdctl
    if command -v nerdctl &> /dev/null && nerdctl version &> /dev/null 2>&1; then
        if [[ ! " ${tools[@]} " =~ "nerdctl" ]]; then
            tools+=("nerdctl")
        fi
    fi
    
    # Check for podman
    if command -v podman &> /dev/null && podman version &> /dev/null 2>&1; then
        tools+=("podman")
    fi
    
    echo "${tools[@]}"
}

detect_kubernetes_runtime() {
    # Check for K3s
    if command -v k3s &> /dev/null || sudo systemctl is-active --quiet k3s; then
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
    
    # Generic containerd
    if sudo ctr version &> /dev/null 2>&1; then
        echo "containerd"
        return 0
    fi
    
    echo "unknown"
}

# ============================================================================
# RECOMMENDATION ENGINE
# ============================================================================

get_recommendation() {
    local runtime="$1"
    local tool="$2"
    
    # Match specific tool, not substring in available_tools
    case "$runtime" in
        "k3s")
            case "$tool" in
                "nerdctl")
                    echo "nerdctl|direct|✅ Best choice: nerdctl builds directly into K3s containerd"
                    ;;
                "podman")
                    echo "podman|save-load|⚠️  Podman works but requires image transfer"
                    ;;
                "docker")
                    echo "docker|save-load|⚠️  Docker works but requires image transfer"
                    ;;
            esac
            ;;
        "colima")
            case "$tool" in
                "docker")
                    echo "docker|save-load|✅ Docker is the standard tool for Colima"
                    ;;
                "nerdctl")
                    echo "nerdctl|save-load|⚠️  nerdctl works but requires transfer"
                    ;;
                "podman")
                    echo "podman|save-load|⚠️  Podman works but requires transfer"
                    ;;
            esac
            ;;
        "docker-desktop")
            case "$tool" in
                "docker")
                    echo "docker|none|✅ Docker Desktop shares images automatically"
                    ;;
                *)
                    echo "$tool|save-load|⚠️  $tool works but may require transfer"
                    ;;
            esac
            ;;
        *)
            # Generic recommendations
            case "$tool" in
                "docker")
                    echo "docker|save-load|✓ Docker is widely compatible"
                    ;;
                "podman")
                    echo "podman|save-load|✓ Podman is a good alternative"
                    ;;
                "nerdctl")
                    echo "nerdctl|save-load|✓ nerdctl is containerd-native"
                    ;;
            esac
            ;;
    esac
}

# ============================================================================
# INTERACTIVE SELECTION
# ============================================================================

select_container_tool() {
    local tools_string="$1"
    local runtime="$2"
    
    IFS=' ' read -ra tools <<< "$tools_string"
    
    # Display menu to stderr so it shows to user (stdout is captured for return value)
    echo "Available Container Build Tools:" >&2
    echo "" >&2
    
    local recommendations=()
    local i=1
    
    # Process each tool and display it with recommendation
    for tool in "${tools[@]}"; do
        local clean_tool=$(echo "$tool" | sed 's/ (via docker alias)//')
        local rec=$(get_recommendation "$runtime" "$clean_tool")
        
        # Display the tool with its number (to stderr for display)
        echo "  $i) $tool" >&2
        
        # Display the recommendation if available
        if [[ -n "$rec" ]]; then
            IFS='|' read -r rec_tool import_method description <<< "$rec"
            echo "     $description" >&2
            recommendations+=("$tool|$import_method")
        else
            # Fallback if no specific recommendation
            echo "     ✓ Available for use" >&2
            recommendations+=("$tool|save-load")
        fi
        
        ((i++))
    done
    
    # If no tools were found at all
    if [[ ${#tools[@]} -eq 0 ]]; then
        echo "Error: No container tools found!" >&2
        exit 1
    fi
    
    echo "" >&2
    read -p "Select container build tool (1-$((i-1))): " selection
    
    if [[ "$selection" -ge 1 ]] && [[ "$selection" -lt "$i" ]]; then
        # This goes to stdout to be captured
        echo "${recommendations[$((selection-1))]}"
    else
        echo "Invalid selection" >&2
        exit 1
    fi
}

# ============================================================================
# CONFIGURATION WRITER
# ============================================================================

write_config() {
    local build_tool="$1"
    local runtime="$2"
    local import_method="$3"
    local detected_tools="$4"
    
    # Clean up tool name
    build_tool=$(echo "$build_tool" | sed 's/ (via docker alias)//')
    
    cat > "$CONFIG_FILE" << EOF
# AI DevKit Container Runtime Configuration
# Generated on $(date)

container:
  build_tool: $build_tool
  runtime: $runtime
  runtime_import: $import_method

detected:
  tools:
$(for tool in $detected_tools; do echo "    - $tool"; done)
  runtime: $runtime
  
preferences:
  auto_detect: false
  prefer_native: true
  
# Configuration can be regenerated by running:
# ./configure-container-runtime.sh
EOF
    
    echo -e "${GREEN}✓${NC} Configuration saved to $CONFIG_FILE"
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_configuration() {
    local build_tool="$1"
    local runtime="$2"
    
    echo ""
    echo -e "${BOLD}Validating configuration...${NC}"
    
    # Clean up tool name for commands
    local cmd_tool=$(echo "$build_tool" | sed 's/ (via docker alias)//')
    if [[ "$build_tool" == *"via docker alias"* ]]; then
        cmd_tool="docker"
    fi
    
    # Test that we can use the build tool
    echo -n "  Testing $build_tool... "
    if $cmd_tool version &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo -e "${RED}Error: Cannot execute $cmd_tool${NC}"
        return 1
    fi
    
    # Test Kubernetes access
    echo -n "  Testing Kubernetes access... "
    if kubectl get nodes &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo -e "${YELLOW}Warning: Cannot access Kubernetes cluster${NC}"
    fi
    
    # Runtime-specific validation
    case "$runtime" in
        "k3s")
            echo -n "  Testing K3s containerd access... "
            if sudo k3s ctr version &> /dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${YELLOW}⚠${NC} May need sudo for image operations"
            fi
            ;;
        "colima")
            echo -n "  Testing Colima status... "
            if colima status &> /dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
                echo -e "${YELLOW}Warning: Colima doesn't appear to be running${NC}"
            fi
            ;;
    esac
    
    return 0
}

# ============================================================================
# MAIN FLOW
# ============================================================================

main() {
    # Check if configuration already exists
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "${YELLOW}Existing configuration found:${NC}"
        echo ""
        grep -E "build_tool:|runtime:|runtime_import:" "$CONFIG_FILE" | sed 's/^/  /'
        echo ""
        read -p "Do you want to reconfigure? (y/N): " reconfigure
        if [[ "$reconfigure" != "y" ]] && [[ "$reconfigure" != "Y" ]]; then
            echo "Keeping existing configuration."
            exit 0
        fi
        echo ""
    fi
    
    # Step 1: Detect available tools
    echo -e "${BOLD}Step 1: Detecting available container tools...${NC}"
    available_tools=$(detect_container_tools)
    
    if [[ -z "$available_tools" ]]; then
        echo -e "${RED}No container tools found!${NC}"
        echo "Please install one of: docker, nerdctl, or podman"
        exit 1
    fi
    
    echo -e "  Found: ${GREEN}$available_tools${NC}"
    echo ""
    
    # Step 2: Detect Kubernetes runtime
    echo -e "${BOLD}Step 2: Detecting Kubernetes runtime...${NC}"
    runtime=$(detect_kubernetes_runtime)
    echo -e "  Detected: ${GREEN}$runtime${NC}"
    echo ""
    
    # Step 3: Get user selection
    echo -e "${BOLD}Step 3: Select container build tool${NC}"
    echo ""
    
    if [[ "$runtime" == "k3s" ]] && [[ "$available_tools" == *"nerdctl"* ]] && [[ "$available_tools" == *"podman"* ]]; then
        echo -e "${CYAN}ℹ️  Note: Both nerdctl and podman are available.${NC}"
        echo -e "${CYAN}   nerdctl is recommended for K3s as it shares the same containerd storage.${NC}"
        echo ""
    fi
    
    selection_result=$(select_container_tool "$available_tools" "$runtime")
    IFS='|' read -r selected_tool import_method <<< "$selection_result"
    
    # Step 4: Validate configuration
    if validate_configuration "$selected_tool" "$runtime"; then
        echo ""
        # Step 5: Write configuration
        echo -e "${BOLD}Step 4: Saving configuration${NC}"
        write_config "$selected_tool" "$runtime" "$import_method" "$available_tools"
        
        echo ""
        echo -e "${GREEN}${BOLD}Configuration complete!${NC}"
        echo ""
        echo "Summary:"
        echo "  Build tool: $selected_tool"
        echo "  Runtime: $runtime"
        echo "  Import method: $import_method"
        echo ""
        echo "You can now run ./build-and-deploy.sh"
    else
        echo ""
        echo -e "${RED}Configuration validation failed.${NC}"
        echo "Please fix the issues above and try again."
        exit 1
    fi
}

# Run main function
main "$@"