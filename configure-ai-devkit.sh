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
    local components=()
    while IFS= read -r comp; do
        components+=("$comp")
    done < <(find_eligible_components)
    
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

# Dual-panel TUI for repository configuration (matching build-and-deploy.sh style)
configure_repositories_tui() {
    local components=("$@")
    
    # Terminal dimensions
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local term_height=$(tput lines 2>/dev/null || echo 24)
    local left_width=$((term_width / 2 - 2))
    local right_start=$((left_width + 3))
    local right_width=$((term_width - right_start - 1))
    local content_height=$((term_height - 8))
    
    # Parse components
    local comp_ids=() comp_names=() comp_formats=() comp_files=()
    comp_map=()
    comp_repos=()
    
    for comp in "${components[@]}"; do
        IFS=':' read -r id name format file <<< "$comp"
        comp_ids+=("$id")
        comp_names+=("$name")
        comp_formats+=("$format")
        comp_files+=("$file")
        comp_map["$id"]="$name:$format:$file"
        comp_repos["$id"]=""
    done
    
    # Get Nexus repositories if available
    local nexus_repos=()
    if [[ "$NEXUS_CONFIGURED" == "true" ]] && [[ -f "$NEXUS_CACHE" ]]; then
        while IFS= read -r repo; do
            nexus_repos+=("$repo")
        done < <(read_nexus_cache)
    fi
    
    # UI state
    local current_comp=0
    local selected_comp=-1
    local view="components"  # components or repos
    
    # Main loop
    while true; do
        clear
        
        # Header
        local header=" AI DevKit Repository Configuration "
        local padding=$(( (term_width - ${#header}) / 2 ))
        printf "\033[0;36m%*s%s%*s\033[0m\n\n" $padding "" "$header" $padding ""
        
        # Left panel - Components
        printf "\033[3;1H"
        printf "╭%s┐ Components ┌%s╮\n" "$(printf '─%.0s' $(seq 1 $((left_width - 14))))" "$(printf '─%.0s' $(seq 1 14))"
        
        # List components with proper formatting
        local comp_idx=0
        for ((row=4; row<4+content_height && comp_idx<${#comp_ids[@]}; row++)); do
            printf "\033[%d;1H│" $row
            
            # Cursor for navigation
            if [[ $comp_idx -eq $current_comp ]]; then
                printf " \033[1;33m▸\033[0m "
            else
                printf "   "
            fi
            
            # Checkbox for configuration status
            if [[ -n "${comp_repos[${comp_ids[$comp_idx]}]}" ]]; then
                printf "\033[0;32m✓\033[0m "  # Green checkmark
            else
                printf "○ "  # Empty circle
            fi
            
            # Component name
            local display="${comp_names[$comp_idx]}"
            if [[ ${#display} -gt $((left_width - 7)) ]]; then
                display="${display:0:$((left_width - 10))}..."
            fi
            
            printf "%-*s│\n" $((left_width - 6)) "$display"
            ((comp_idx++))
        done
        
        # Fill empty rows
        for ((row=4+comp_idx; row<4+content_height; row++)); do
            printf "\033[%d;1H│%*s│\n" $row $((left_width - 1)) ""
        done
        
        # Bottom border
        printf "\033[%d;1H╰%s╯\n" $((4 + content_height)) "$(printf '─%.0s' $(seq 1 $((left_width - 1))))"
        
        # Right panel - Available Repositories
        printf "\033[3;%dH" $right_start
        printf "╭%s┐ Available Repositories ┌%s╮\n" "$(printf '─%.0s' $(seq 1 $((right_width - 27))))" "$(printf '─%.0s' $(seq 1 27))"
        
        # Show repos for selected component
        if [[ $selected_comp -ge 0 ]] && [[ $selected_comp -lt ${#comp_ids[@]} ]]; then
            local format="${comp_formats[$selected_comp]}"
            printf "\033[4;%dH│ \033[1;34mFormat: %s\033[0m%*s│\n" $right_start "$format" $((right_width - 10 - ${#format})) ""
            printf "\033[5;%dH│%*s│\n" $right_start $((right_width - 1)) ""
            
            local row=6
            
            # Show matching Nexus repositories
            if [[ ${#nexus_repos[@]} -gt 0 ]]; then
                local found_nexus=false
                for repo in "${nexus_repos[@]}"; do
                    IFS=':' read -r repo_name type fmt url <<< "$repo"
                    if [[ "$fmt" == "$format" ]]; then
                        if [[ $found_nexus == false ]]; then
                            printf "\033[%d;%dH│ \033[1;32mNexus Repositories:\033[0m%*s│\n" $row $right_start $((right_width - 21)) ""
                            ((row++))
                            found_nexus=true
                        fi
                        
                        local display="  • $repo_name ($type)"
                        if [[ ${#display} -gt $((right_width - 2)) ]]; then
                            display="${display:0:$((right_width - 5))}..."
                        fi
                        printf "\033[%d;%dH│%-*s│\n" $row $right_start $((right_width - 1)) "$display"
                        ((row++))
                        
                        if [[ $row -ge $((4 + content_height)) ]]; then
                            break
                        fi
                    fi
                done
            fi
            
            # Show recommended repositories
            if [[ $row -lt $((4 + content_height - 1)) ]]; then
                local recommended=$(get_recommended_repositories "${comp_files[$selected_comp]}")
                if [[ -n "$recommended" ]]; then
                    printf "\033[%d;%dH│%*s│\n" $row $right_start $((right_width - 1)) ""
                    ((row++))
                    printf "\033[%d;%dH│ \033[1;36mRecommended:\033[0m%*s│\n" $row $right_start $((right_width - 15)) ""
                    ((row++))
                    
                    while IFS= read -r rec && [[ $row -lt $((4 + content_height)) ]]; do
                        IFS=':' read -r rec_name rec_url rec_type _ <<< "$rec"
                        local display="  • $rec_name"
                        if [[ ${#display} -gt $((right_width - 2)) ]]; then
                            display="${display:0:$((right_width - 5))}..."
                        fi
                        printf "\033[%d;%dH│%-*s│\n" $row $right_start $((right_width - 1)) "$display"
                        ((row++))
                    done <<< "$recommended"
                fi
            fi
            
            # Fill remaining space
            for ((; row<4+content_height; row++)); do
                printf "\033[%d;%dH│%*s│\n" $row $right_start $((right_width - 1)) ""
            done
        else
            # No component selected
            printf "\033[4;%dH│ \033[0;33mSelect a component to see\033[0m%*s│\n" $right_start $((right_width - 27)) ""
            printf "\033[5;%dH│ \033[0;33mavailable repositories\033[0m%*s│\n" $right_start $((right_width - 24)) ""
            
            for ((row=6; row<4+content_height; row++)); do
                printf "\033[%d;%dH│%*s│\n" $row $right_start $((right_width - 1)) ""
            done
        fi
        
        # Bottom border
        printf "\033[%d;%dH╰%s╯\n" $((4 + content_height)) $right_start "$(printf '─%.0s' $(seq 1 $((right_width - 1))))"
        
        # Instructions
        printf "\n"
        printf "  \033[1m↑↓/jk\033[0m Navigate  \033[1mSPACE\033[0m Configure  \033[1mENTER\033[0m Select  \033[1ms\033[0m Save  \033[1mq\033[0m Cancel\n"
        
        # Read input
        read -rsn1 key
        
        case "$key" in
            q|Q)
                break
                ;;
            s|S)
                save_repository_configuration
                break
                ;;
            ' ')  # SPACE - configure component
                selected_comp=$current_comp
                configure_single_component "${comp_ids[$current_comp]}" "${comp_map[${comp_ids[$current_comp]}]}"
                ;;
            $'\n')  # ENTER - select component
                selected_comp=$current_comp
                ;;
            j)  # vim down
                [[ $current_comp -lt $((${#comp_ids[@]} - 1)) ]] && ((current_comp++))
                ;;
            k)  # vim up
                [[ $current_comp -gt 0 ]] && ((current_comp--))
                ;;
            $'\x1b')  # ESC sequence for arrows
                read -rsn2 -t 0.1 seq
                case "$seq" in
                    '[A')  # Up arrow
                        [[ $current_comp -gt 0 ]] && ((current_comp--))
                        ;;
                    '[B')  # Down arrow
                        [[ $current_comp -lt $((${#comp_ids[@]} - 1)) ]] && ((current_comp++))
                        ;;
                esac
                ;;
        esac
    done
}

# Configure repositories for a single component
configure_single_component() {
    local id="$1"
    local info="$2"
    
    IFS=':' read -r name format file <<< "$info"
    
    clear
    echo -e "${CYAN}=== Configure Repository for $name ===${NC}"
    echo ""
    echo -e "${BLUE}Component:${NC} $name"
    echo -e "${BLUE}Format:${NC} $format"
    echo ""
    
    # Show current configuration if exists
    if [[ -n "${comp_repos[$id]}" ]]; then
        echo -e "${GREEN}Current Configuration:${NC}"
        IFS='|' read -r repo_name repo_url _ _ _ <<< "${comp_repos[$id]}"
        echo "  Repository: $repo_name"
        echo "  URL: $repo_url"
        echo ""
    fi
    
    echo -e "${YELLOW}Available Options:${NC}"
    echo ""
    
    local options=()
    local option_index=1
    
    # List Nexus repositories
    if [[ "$NEXUS_CONFIGURED" == "true" ]] && [[ -f "$NEXUS_CACHE" ]]; then
        echo -e "${BLUE}Nexus Repositories:${NC}"
        local nexus_found=false
        while IFS= read -r repo; do
            IFS=':' read -r repo_name type fmt url <<< "$repo"
            if [[ "$fmt" == "$format" ]]; then
                echo "  $option_index) $repo_name ($type)"
                echo "     $url"
                options+=("nexus|${repo_name}|${url}|local_readonly|inherit|true")
                ((option_index++))
                nexus_found=true
            fi
        done < <(read_nexus_cache)
        
        if [[ $nexus_found == false ]]; then
            echo "  (No $format repositories in Nexus)"
        fi
        echo ""
    fi
    
    # List recommended repositories
    echo -e "${GREEN}Recommended Repositories:${NC}"
    local recommended=$(get_recommended_repositories "$file")
    if [[ -n "$recommended" ]]; then
        while IFS= read -r repo; do
            IFS=':' read -r repo_name url type reason <<< "$repo"
            echo "  $option_index) $repo_name"
            echo "     $url"
            [[ -n "$reason" ]] && echo "     ($reason)"
            options+=("recommended|${repo_name}|${url}|${type}|anonymous|false")
            ((option_index++))
        done <<< "$recommended"
    else
        echo "  (No recommendations available)"
    fi
    
    echo ""
    echo "Other options:"
    echo "  C) Custom repository"
    echo "  N) No repository (use defaults)"
    echo "  B) Back"
    echo ""
    
    read -p "Select option: " choice
    
    case "$choice" in
        [0-9]*)
            if [[ $choice -ge 1 ]] && [[ $choice -le ${#options[@]} ]]; then
                IFS='|' read -r _ repo_name repo_url repo_type repo_auth repo_primary <<< "${options[$((choice-1))]}"
                comp_repos["$id"]="${repo_name}|${repo_url}|${repo_type}|${repo_auth}|${repo_primary}"
                echo -e "\n${GREEN}✓ Configured: $repo_name${NC}"
                sleep 1
            else
                echo -e "\n${RED}Invalid option${NC}"
                sleep 1
            fi
            ;;
        c|C)
            echo ""
            read -p "Repository name: " custom_name
            read -p "Repository URL: " custom_url
            if [[ -n "$custom_name" ]] && [[ -n "$custom_url" ]]; then
                comp_repos["$id"]="${custom_name}|${custom_url}|remote|anonymous|true"
                echo -e "\n${GREEN}✓ Custom repository configured${NC}"
                sleep 1
            else
                echo -e "\n${RED}Name and URL are required${NC}"
                sleep 1
            fi
            ;;
        n|N)
            comp_repos["$id"]=""
            echo -e "\n${YELLOW}✓ Cleared - will use defaults${NC}"
            sleep 1
            ;;
        b|B)
            # Just return
            ;;
        *)
            echo -e "\n${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
}

# Save repository configuration
save_repository_configuration() {
    echo ""
    echo -e "${CYAN}Saving repository configuration...${NC}"
    
    # Check if component_repos section exists
    if ! grep -q "^component_repos:" "$CONFIG_FILE" 2>/dev/null; then
        echo "" >> "$CONFIG_FILE"
        echo "# Component repository configuration" >> "$CONFIG_FILE"
        echo "component_repos:" >> "$CONFIG_FILE"
    fi
    
    # Save each configured component
    for id in "${!comp_repos[@]}"; do
        if [[ -n "${comp_repos[$id]}" ]]; then
            # Remove existing config for this component if it exists
            sed -i "/^  $id:/,/^  [^ ]\|^[^ ]/{ /^  $id:/d; /^    /d; }" "$CONFIG_FILE" 2>/dev/null || true
            
            # Add new config
            echo "  $id:" >> "$CONFIG_FILE"
            
            # Parse repository configuration
            IFS='|' read -r repo_name repo_url repo_type repo_auth repo_primary <<< "${comp_repos[$id]}"
            echo "    - name: \"$repo_name\"" >> "$CONFIG_FILE"
            echo "      url: \"$repo_url\"" >> "$CONFIG_FILE"
            echo "      type: \"$repo_type\"" >> "$CONFIG_FILE"
            echo "      auth: \"$repo_auth\"" >> "$CONFIG_FILE"
            echo "      primary: ${repo_primary:-true}" >> "$CONFIG_FILE"
        fi
    done
    
    echo -e "${GREEN}✓ Repository configuration saved to $CONFIG_FILE${NC}"
    sleep 1
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