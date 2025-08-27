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

echo -e "${CYAN}=== AI DevKit Configuration ===${NC}"
echo ""
echo -e "This script will configure:"
echo -e "  1. Container runtime (Docker, Podman, nerdctl)"
echo -e "  2. Repository managers (Nexus, PyPI, NPM, etc.)"
echo ""
echo -e "${BLUE}Step 1: Container Runtime Configuration${NC}"
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

# Removed detect_nexus function - using explicit user configuration instead
# Old auto-detection was brittle and made incorrect assumptions

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

# Simple Nexus configuration - ask the user directly
echo ""
echo -e "${BLUE}Basic Nexus Configuration${NC}"
echo -e "${YELLOW}For advanced repository configuration, see Step 2 below.${NC}"
echo ""

nexus_enabled="false"
nexus_url=""

read -p "Do you want to configure a Nexus repository manager? (y/N): " configure_nexus

if [[ "$configure_nexus" =~ ^[Yy] ]]; then
    echo ""
    read -p "Enter Nexus URL (e.g., http://nexus.example.com:8081): " nexus_url
    
    if [[ -n "$nexus_url" ]]; then
        # Remove trailing slash if present
        nexus_url="${nexus_url%/}"
        
        # Validate URL format
        if [[ "$nexus_url" =~ ^https?:// ]]; then
            nexus_enabled="true"
            echo ""
            echo -e "${GREEN}✓${NC} Nexus configured: $nexus_url"
        else
            echo -e "${RED}Invalid URL format. Must start with http:// or https://${NC}"
            echo -e "${YELLOW}Skipping Nexus configuration.${NC}"
            nexus_enabled="false"
            nexus_url=""
        fi
    else
        echo -e "${YELLOW}No URL provided, skipping Nexus configuration.${NC}"
        nexus_enabled="false"
    fi
else
    echo -e "${YELLOW}Skipping Nexus configuration.${NC}"
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

# Save initial configuration (will be updated if repositories are configured)
echo -e "${GREEN}✓${NC} Container runtime configuration saved"
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

# ============================================================================
# REPOSITORY CONFIGURATION FUNCTIONS
# ============================================================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source repository configuration library
if [[ -f "${SCRIPT_DIR}/lib/repository-config.sh" ]]; then
    source "${SCRIPT_DIR}/lib/repository-config.sh"
else
    echo -e "${YELLOW}Warning: Repository configuration library not found${NC}"
fi

# Terminal handling for TUI
setup_terminal() {
    # Save current terminal settings
    SAVED_STTY=$(stty -g 2>/dev/null)
    # Hide cursor
    tput civis 2>/dev/null || true
    # Clear screen
    clear
}

cleanup_terminal() {
    # Restore terminal settings
    [[ -n "$SAVED_STTY" ]] && stty "$SAVED_STTY" 2>/dev/null
    # Show cursor
    tput cnorm 2>/dev/null || true
    # Clear screen
    clear
}

# Function to configure component repositories
configure_component_repositories() {
    echo ""
    echo -e "${CYAN}=== Repository Configuration ===${NC}"
    echo ""
    
    # Load eligible components
    echo "Scanning for eligible components..."
    local components=($(find_eligible_components))
    
    if [[ ${#components[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No components with repository support found.${NC}"
        return
    fi
    
    echo -e "${GREEN}Found ${#components[@]} components with repository support${NC}"
    echo ""
    
    # Configure Nexus (optional)
    configure_nexus_repository
    
    # Configure component repositories
    echo ""
    echo -e "${BLUE}Configuring component repositories...${NC}"
    echo -e "${YELLOW}This will open an interactive interface for selecting repositories.${NC}"
    echo ""
    read -p "Press Enter to continue..." -r
    
    # Run the dual-panel TUI
    setup_terminal
    trap cleanup_terminal EXIT INT TERM
    
    configure_repositories_tui "${components[@]}"
    
    cleanup_terminal
    trap - EXIT INT TERM
    
    echo ""
    echo -e "${GREEN}✓ Repository configuration complete${NC}"
}

# Function to configure Nexus
configure_nexus_repository() {
    echo -e "${BLUE}Nexus Repository Manager Configuration${NC}"
    echo ""
    read -p "Do you have a Nexus repository manager? (y/N): " has_nexus
    
    if [[ ! "$has_nexus" =~ ^[Yy] ]]; then
        return
    fi
    
    echo ""
    read -p "Enter Nexus URL (e.g., http://nexus.example.com:8081): " nexus_url
    
    if [[ -z "$nexus_url" ]]; then
        echo -e "${YELLOW}No URL provided, skipping Nexus configuration${NC}"
        return
    fi
    
    # Remove trailing slash
    nexus_url="${nexus_url%/}"
    
    echo ""
    echo "Select authentication type:"
    echo "  1) Anonymous (no authentication)"
    echo "  2) Basic authentication (username/password)"
    echo ""
    read -p "Select (1-2) [1]: " auth_choice
    
    local auth_type="anonymous"
    local username=""
    local password=""
    
    if [[ "$auth_choice" == "2" ]]; then
        auth_type="basic"
        read -p "Username: " username
        read -s -p "Password: " password
        echo ""
    fi
    
    echo ""
    echo -e "${CYAN}Connecting to Nexus...${NC}"
    
    # Fetch and cache repository list
    local repos=$(fetch_nexus_repositories "$nexus_url" "$auth_type" "$username" "$password")
    
    if [[ $? -eq 0 ]] && [[ -n "$repos" ]]; then
        cache_nexus_repositories "$nexus_url" $repos
        echo -e "${GREEN}✓ Connected successfully${NC}"
        
        # Update config with Nexus settings
        cat >> "$CONFIG_FILE" << EOF

# Nexus configuration (updated)
nexus:
  enabled: true
  url: "$nexus_url"
  auth:
    type: "$auth_type"
EOF
        
        if [[ "$auth_type" == "basic" ]]; then
            cat >> "$CONFIG_FILE" << EOF
    username: "$username"
    password: "encrypted:$(encrypt_password "$password")"
EOF
        fi
        
        NEXUS_CONFIGURED=true
        export NEXUS_URL="$nexus_url"
        export NEXUS_AUTH_TYPE="$auth_type"
        export NEXUS_USERNAME="$username"
        export NEXUS_PASSWORD="$password"
    else
        echo -e "${RED}✗ Failed to connect to Nexus${NC}"
        NEXUS_CONFIGURED=false
    fi
}

# Global arrays for repository configuration
declare -A comp_map
declare -A comp_repos

# Simplified TUI for repository configuration
configure_repositories_tui() {
    local components=("$@")
    local selected_repos=""
    
    # Clear and parse components
    comp_map=()
    comp_repos=()
    
    for comp in "${components[@]}"; do
        IFS=':' read -r id name format file <<< "$comp"
        comp_map["$id"]="$name:$format:$file"
        comp_repos["$id"]=""
    done
    
    # Simple menu-based selection
    while true; do
        clear
        echo -e "${CYAN}=== Component Repository Configuration ===${NC}"
        echo ""
        echo "Select a component to configure repositories:"
        echo ""
        
        local index=1
        local ids=()
        
        for id in "${!comp_map[@]}"; do
            IFS=':' read -r name format file <<< "${comp_map[$id]}"
            local repo_count=0
            [[ -n "${comp_repos[$id]}" ]] && repo_count=$(echo "${comp_repos[$id]}" | tr '|' '\n' | grep -c .)
            echo "  $index) $name ($format) - $repo_count repositories configured"
            ids+=("$id")
            ((index++))
        done
        
        echo ""
        echo "  S) Save and exit"
        echo "  Q) Quit without saving"
        echo ""
        read -p "Select option: " choice
        
        if [[ "$choice" == "S" ]] || [[ "$choice" == "s" ]]; then
            # Save configuration
            save_repository_configuration
            break
        elif [[ "$choice" == "Q" ]] || [[ "$choice" == "q" ]]; then
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "${#ids[@]}" ]]; then
            local selected_id="${ids[$((choice-1))]}"
            configure_single_component "$selected_id" "${comp_map[$selected_id]}"
        fi
    done
}

# Configure repositories for a single component
configure_single_component() {
    local id="$1"
    local info="$2"
    
    IFS=':' read -r name format file <<< "$info"
    
    clear
    echo -e "${CYAN}=== Configure Repositories for $name ===${NC}"
    echo ""
    echo "Format: $format"
    echo ""
    
    # Show Nexus repositories if available
    if [[ "$NEXUS_CONFIGURED" == "true" ]] && [[ -f "$NEXUS_CACHE" ]]; then
        echo -e "${BLUE}Available Nexus Repositories:${NC}"
        local nexus_repos=$(read_nexus_cache | grep ":$format:")
        if [[ -n "$nexus_repos" ]]; then
            while IFS= read -r repo; do
                IFS=':' read -r repo_name type fmt url <<< "$repo"
                echo "  • $repo_name ($type) - $url"
            done <<< "$nexus_repos"
        else
            echo "  (No $format repositories in Nexus)"
        fi
        echo ""
    fi
    
    # Show recommended repositories
    echo -e "${GREEN}Recommended Repositories:${NC}"
    local recommended=$(get_recommended_repositories "$file")
    if [[ -n "$recommended" ]]; then
        while IFS= read -r repo; do
            IFS=':' read -r repo_name url type reason <<< "$repo"
            echo "  • $repo_name - $url"
        done <<< "$recommended"
    else
        echo "  (No recommendations)"
    fi
    
    echo ""
    echo "Current configuration: ${comp_repos[$id]:-None}"
    echo ""
    echo "Options:"
    echo "  1) Use recommended repositories"
    echo "  2) Use Nexus repositories"
    echo "  3) Custom configuration"
    echo "  4) Clear configuration"
    echo "  5) Back"
    echo ""
    read -p "Select option: " opt
    
    case "$opt" in
        1)
            # Use recommended
            if [[ -n "$recommended" ]]; then
                local repo_config=""
                while IFS= read -r repo; do
                    IFS=':' read -r repo_name url type reason <<< "$repo"
                    [[ -n "$repo_config" ]] && repo_config+="|"
                    repo_config+="${repo_name}|${url}|${type}|anonymous|false"
                done <<< "$recommended"
                comp_repos["$id"]="$repo_config"
                echo -e "${GREEN}✓ Configured with recommended repositories${NC}"
            fi
            ;;
        2)
            # Use Nexus
            if [[ "$NEXUS_CONFIGURED" == "true" ]]; then
                local nexus_repos=$(read_nexus_cache | grep ":$format:" | head -1)
                if [[ -n "$nexus_repos" ]]; then
                    IFS=':' read -r repo_name type fmt url <<< "$nexus_repos"
                    comp_repos["$id"]="${repo_name}|${url}|local_readonly|inherit|true"
                    echo -e "${GREEN}✓ Configured with Nexus repository${NC}"
                fi
            fi
            ;;
        3)
            # Custom
            read -p "Repository name: " repo_name
            read -p "Repository URL: " repo_url
            if [[ -n "$repo_name" ]] && [[ -n "$repo_url" ]]; then
                comp_repos["$id"]="${repo_name}|${repo_url}|remote|anonymous|true"
                echo -e "${GREEN}✓ Custom repository configured${NC}"
            fi
            ;;
        4)
            # Clear
            comp_repos["$id"]=""
            echo -e "${YELLOW}✓ Configuration cleared${NC}"
            ;;
    esac
    
    [[ "$opt" != "5" ]] && read -p "Press Enter to continue..."
}

# Save repository configuration
save_repository_configuration() {
    echo ""
    echo -e "${CYAN}Saving repository configuration...${NC}"
    
    # Append component repositories to config
    echo "" >> "$CONFIG_FILE"
    echo "# Component repository configuration" >> "$CONFIG_FILE"
    echo "component_repos:" >> "$CONFIG_FILE"
    
    for id in "${!comp_repos[@]}"; do
        if [[ -n "${comp_repos[$id]}" ]]; then
            echo "  $id:" >> "$CONFIG_FILE"
            
            # Parse and save each repository
            IFS='|' read -ra repos <<< "${comp_repos[$id]}"
            local i=0
            while [[ $i -lt ${#repos[@]} ]]; do
                echo "    - name: \"${repos[$i]}\"" >> "$CONFIG_FILE"
                echo "      url: \"${repos[$((i+1))]}\"" >> "$CONFIG_FILE"
                echo "      type: \"${repos[$((i+2))]}\"" >> "$CONFIG_FILE"
                echo "      auth: \"${repos[$((i+3))]}\"" >> "$CONFIG_FILE"
                echo "      primary: ${repos[$((i+4))]}" >> "$CONFIG_FILE"
                i=$((i+5))
            done
        fi
    done
    
    echo -e "${GREEN}✓ Repository configuration saved${NC}"
}

# Ask about repository configuration
echo -e "${BLUE}Step 2: Repository Configuration${NC}"
echo -e "${YELLOW}Configure artifact repositories for your components (Nexus, PyPI, NPM, etc.)${NC}"
echo ""
read -p "Configure repositories now? (y/N): " configure_repos

if [[ "$configure_repos" =~ ^[Yy] ]]; then
    configure_component_repositories
else
    echo ""
    echo -e "${YELLOW}Skipping repository configuration.${NC}"
    echo -e "You can re-run this script later to configure repositories."
fi

echo ""
echo -e "${GREEN}=== Configuration Complete ===${NC}"
echo ""
echo -e "You can now run: ${BOLD}./build-and-deploy.sh${NC} to build and deploy components"
echo ""
echo -e "To reconfigure, run: ${BOLD}./configure-ai-devkit.sh${NC} again"