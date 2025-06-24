#!/bin/bash
# This script requires bash 3.2 or higher
set -e

# Configuration
IMAGE_NAME="ai-devkit"
IMAGE_TAG="latest"
NAMESPACE="ai-devkit"
TEMP_DIR=".build-temp"
COMPONENTS_DIR="components"
SSH_KEYS_DIR="$HOME/.ai-devkit-k8s/ssh-keys"
LOG_FILE="build-and-deploy.log"

# ============================================================================
# SPECIAL CHARACTERS AND KEYCODES
# ============================================================================

# Special characters
readonly NL=$'\n'
readonly TAB=$'\t'
readonly CR=$'\r'
readonly ESC=$'\e'
readonly BACKSPACE=$'\x7f'
readonly NULL=$'\0'

# ============================================================================
# THEME SYSTEM - ENHANCED GRANULARITY
# ============================================================================

# Base colors
readonly COLOR_BLACK='\033[0;30m'                    # #000000
readonly COLOR_RED='\033[0;31m'                      # #800000
readonly COLOR_GREEN='\033[0;32m'                    # #008000
readonly COLOR_YELLOW='\033[0;33m'                   # #808000
readonly COLOR_BLUE='\033[0;34m'                     # #000080
readonly COLOR_MAGENTA='\033[0;35m'                  # #800080
readonly COLOR_CYAN='\033[0;36m'                     # #008080
readonly COLOR_WHITE='\033[0;37m'                    # #C0C0C0
readonly COLOR_GRAY='\033[0;90m'                     # #555555

# Custom base colors (from hex codes)
readonly COLOR_SILVER='\033[38;2;171;178;191m'       # #ABB2BF
readonly COLOR_CHARCOAL='\033[38;2;92;99;112m'       # #5C6370
readonly COLOR_SKY='\033[38;2;97;175;239m'           # #61AFEF
readonly COLOR_SAGE='\033[38;2;178;193;121m'         # #B2C179
readonly COLOR_CORAL='\033[38;2;224;108;117m'        # #E06C75
readonly COLOR_SAND='\033[38;2;229;192;123m'         # #E5C07B
readonly COLOR_SEAFOAM='\033[38;2;138;191;183m'      # #8ABFB7
readonly COLOR_LAVENDER='\033[38;2;198;120;221m'     # #C678DD

# Bright colors
readonly COLOR_BRIGHT_RED='\033[0;91m'                # #FF0000
readonly COLOR_BRIGHT_GREEN='\033[0;92m'              # #00FF00
readonly COLOR_BRIGHT_YELLOW='\033[0;93m'             # #FFFF00
readonly COLOR_BRIGHT_BLUE='\033[0;94m'               # #0000FF
readonly COLOR_BRIGHT_MAGENTA='\033[0;95m'            # #FF00FF
readonly COLOR_BRIGHT_CYAN='\033[0;96m'               # #00FFFF
readonly COLOR_BRIGHT_WHITE='\033[0;97m'              # #FFFFFF
readonly COLOR_BRIGHT_LAVENDER='\033[38;2;218;140;241m'   # #DA8CF1

# Custom bright colors (from hex codes - slightly brightened)
readonly COLOR_BRIGHT_SILVER='\033[38;2;193;200;213m'     # #C1C8D5
readonly COLOR_BRIGHT_CHARCOAL='\033[38;2;112;119;132m'   # #707784
readonly COLOR_BRIGHT_SKY='\033[38;2;127;195;255m'        # #7FC3FF
readonly COLOR_BRIGHT_SAGE='\033[38;2;198;213;141m'       # #C6D58D
readonly COLOR_BRIGHT_CORAL='\033[38;2;244;128;137m'      # #F48089
readonly COLOR_BRIGHT_SAND='\033[38;2;249;212;143m'       # #F9D48F
readonly COLOR_BRIGHT_SEAFOAM='\033[38;2;158;211;203m'    # #9ED3CB
readonly BOLD_BRIGHT_WHITE='\033[1;97m'               # #FFFFFF (bold)

# Styles
readonly STYLE_BOLD='\033[1m'
readonly STYLE_DIM='\033[2m'
readonly STYLE_ITALIC='\033[3m'
readonly STYLE_UNDERLINE='\033[4m'
readonly STYLE_BLINK='\033[5m'
readonly STYLE_REVERSE='\033[7m'
readonly STYLE_RESET='\033[0m'

# Compound styles
readonly BOLD_RED='\033[1;31m'                       # #800000 (bold)
readonly BOLD_GREEN='\033[1;32m'                     # #008000 (bold)
readonly BOLD_YELLOW='\033[1;33m'                    # #808000 (bold)
readonly BOLD_BLUE='\033[1;34m'                      # #000080 (bold)
readonly BOLD_MAGENTA='\033[1;35m'                   # #800080 (bold)
readonly BOLD_CYAN='\033[1;36m'                      # #008080 (bold)
readonly BOLD_WHITE='\033[1;37m'                     # #C0C0C0 (bold)

# Custom bold colors (from hex codes)
readonly BOLD_SILVER='\033[1;38;2;171;178;191m'      # #ABB2BF (bold)
readonly BOLD_CHARCOAL='\033[1;38;2;92;99;112m'      # #5C6370 (bold)
readonly BOLD_SKY='\033[1;38;2;97;175;239m'          # #61AFEF (bold)
readonly BOLD_SAGE='\033[1;38;2;178;193;121m'        # #B2C179 (bold)
readonly BOLD_CORAL='\033[1;38;2;224;108;117m'       # #E06C75 (bold)
readonly BOLD_SAND='\033[1;38;2;229;192;123m'        # #E5C07B (bold)
readonly BOLD_SEAFOAM='\033[1;38;2;138;191;183m'     # #8ABFB7 (bold)
readonly BOLD_LAVENDER='\033[1;38;2;198;120;221m'    # #C678DD

# Icons
readonly ICON_SELECTED="✓"
readonly ICON_AVAILABLE="○"
readonly ICON_DISABLED="○"
readonly ICON_CURSOR="▸"
readonly ICON_CHECKMARK="✓"
readonly ICON_WARNING="⚠️"
readonly ICON_INFO="ℹ️"
readonly ICON_SUCCESS="✓"
readonly ICON_PENDING="⟳"
readonly ICON_FAILED="✗"

# Box Drawing Characters
readonly BOX_TOP_LEFT="╭"
readonly BOX_TOP_RIGHT="╮"
readonly BOX_BOTTOM_LEFT="╰"
readonly BOX_BOTTOM_RIGHT="╯"
readonly BOX_HORIZONTAL="─"
readonly BOX_VERTICAL="│"
readonly BOX_TITLE_LEFT="┐"
readonly BOX_TITLE_RIGHT="┌"
readonly BOX_SEPARATOR="━"

# Global UI Elements
GLOBAL_TITLE_STYLE="$BOLD_BRIGHT_WHITE"
GLOBAL_SEPARATOR_COLOR="$COLOR_RED" # deprecated
GLOBAL_HINT_STYLE="$COLOR_YELLOW"

# Global variable for deployment status row tracking
DEPLOYMENT_STATUS_FINAL_ROW=0

# Catalog Box (Available Components)
CATALOG_BORDER_COLOR="$COLOR_BRIGHT_CHARCOAL"
CATALOG_TITLE_STYLE="$BOLD_BRIGHT_WHITE"
CATALOG_CATEGORY_STYLE="$COLOR_SEAFOAM"
CATALOG_CURSOR_COLOR="$COLOR_BRIGHT_BLUE"
CATALOG_ITEM_SELECTED_STYLE="$COLOR_BRIGHT_SAGE"
CATALOG_ITEM_AVAILABLE_STYLE="$COLOR_BRIGHT_WHITE"
CATALOG_ITEM_DISABLED_STYLE="$COLOR_GRAY"
CATALOG_STATUS_IN_STACK_STYLE="$COLOR_BRIGHT_SAGE"
CATALOG_STATUS_REQUIRED_STYLE="$COLOR_SAND"
CATALOG_PAGE_INDICATOR_STYLE="$COLOR_SAND"
CATALOG_ICON_SELECTED_COLOR="$COLOR_BRIGHT_SAGE"
CATALOG_ICON_AVAILABLE_COLOR="$STYLE_RESET"
CATALOG_ICON_DISABLED_COLOR="$COLOR_GRAY"
CATALOG_ICON_WARNING_COLOR="$COLOR_MAGENTA"

# Cart Box (Build Stack)
CART_BORDER_COLOR="$COLOR_BRIGHT_CHARCOAL"
CART_TITLE_STYLE="$BOLD_BRIGHT_WHITE"
CART_CATEGORY_STYLE="$COLOR_BRIGHT_SEAFOAM"
CART_CURSOR_COLOR="$COLOR_BRIGHT_BLUE"
CART_ITEM_STYLE="$COLOR_BRIGHT_SAGE"
CART_BASE_CATEGORY_STYLE="$COLOR_SEAFOAM"
CART_BASE_ITEM_STYLE="$COLOR_SILVER"
CART_REMOVE_HINT_STYLE="$COLOR_WHITE"
CART_COUNT_STYLE="$COLOR_SAND"

# Instructions Bar
INSTRUCTION_KEY_STYLE="$COLOR_BRIGHT_SKY"
INSTRUCTION_TEXT_STYLE="$COLOR_SILVER"

# Summary Screen
SUMMARY_BORDER_COLOR="$COLOR_SAGE"
SUMMARY_TITLE_STYLE="$BOLD_BRIGHT_WHITE"
SUMMARY_CHECKMARK_COLOR="$COLOR_BRIGHT_SAGE"
SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_SEAFOAM"

# Deployment Status
STATUS_BORDER_COLOR="$COLOR_BRIGHT_CHARCOAL"
STATUS_TITLE_STYLE="$BOLD_BRIGHT_WHITE"
STATUS_PENDING_STYLE="$COLOR_SAND"
STATUS_RUNNING_STYLE="$COLOR_BRIGHT_SKY"
STATUS_SUCCESS_STYLE="$COLOR_BRIGHT_SAGE"
STATUS_FAILED_STYLE="$COLOR_BRIGHT_CORAL"
STATUS_STEP_STYLE="$COLOR_SILVER"
STATUS_INFO_STYLE="$COLOR_BRIGHT_CYAN"

# Logging
LOG_ERROR_STYLE="$COLOR_RED"
LOG_SUCCESS_STYLE="$COLOR_GREEN"
LOG_WARNING_STYLE="$BOLD_YELLOW"
LOG_INFO_STYLE="$COLOR_BLUE"
LOG_DEFAULT_STYLE="$COLOR_YELLOW"

# Theme selection
THEME="${AI_DEVKIT_THEME:-default}"

# Load theme
load_theme() {
    case "$THEME" in
        "dark")
            # Dark theme - softer colors for dark terminals
            GLOBAL_SEPARATOR_COLOR="$COLOR_GRAY"
            GLOBAL_TITLE_STYLE="$BOLD_CYAN"
            
            CATALOG_BORDER_COLOR="$COLOR_GRAY"
            CATALOG_TITLE_STYLE="$BOLD_CYAN"
            CATALOG_CATEGORY_STYLE="$COLOR_MAGENTA"
            CATALOG_CURSOR_COLOR="$COLOR_CYAN"
            CATALOG_ITEM_SELECTED_STYLE="$COLOR_BRIGHT_CYAN"
            CATALOG_STATUS_IN_STACK_STYLE="$COLOR_BRIGHT_CYAN"
            CATALOG_ICON_SELECTED_COLOR="$COLOR_BRIGHT_CYAN"
            
            CART_BORDER_COLOR="$COLOR_GRAY"
            CART_TITLE_STYLE="$BOLD_CYAN"
            CART_CATEGORY_STYLE="$COLOR_MAGENTA"
            CART_CURSOR_COLOR="$COLOR_BRIGHT_MAGENTA"
            CART_ITEM_STYLE="$COLOR_BRIGHT_WHITE"
            
            GLOBAL_HINT_STYLE="$COLOR_BRIGHT_YELLOW"
            
            SUMMARY_BORDER_COLOR="$COLOR_GRAY"
            SUMMARY_CATEGORY_STYLE="$COLOR_MAGENTA"

            STATUS_BORDER_COLOR="$COLOR_GRAY"
            STATUS_TITLE_STYLE="$BOLD_CYAN"
            ;;
            
        "matrix")
            # Matrix theme - green on black
            GLOBAL_SEPARATOR_COLOR="$COLOR_GREEN"
            GLOBAL_TITLE_STYLE="$BOLD_GREEN"
            GLOBAL_HINT_STYLE="$BOLD_GREEN"
            
            CATALOG_BORDER_COLOR="$COLOR_GREEN"
            CATALOG_TITLE_STYLE="$BOLD_GREEN"
            CATALOG_CATEGORY_STYLE="$COLOR_BRIGHT_GREEN"
            CATALOG_CURSOR_COLOR="$BOLD_GREEN"
            CATALOG_ITEM_SELECTED_STYLE="$BOLD_GREEN"
            CATALOG_ITEM_AVAILABLE_STYLE="$COLOR_GREEN"
            CATALOG_ITEM_DISABLED_STYLE="$COLOR_GREEN"
            CATALOG_STATUS_IN_STACK_STYLE="$BOLD_GREEN"
            CATALOG_STATUS_REQUIRED_STYLE="$COLOR_BRIGHT_GREEN"
            CATALOG_PAGE_INDICATOR_STYLE="$COLOR_BRIGHT_GREEN"
            CATALOG_ICON_SELECTED_COLOR="$BOLD_GREEN"
            CATALOG_ICON_AVAILABLE_COLOR="$COLOR_GREEN"
            CATALOG_ICON_DISABLED_COLOR="$COLOR_GREEN"
            CATALOG_ICON_WARNING_COLOR="$COLOR_BRIGHT_GREEN"
            
            CART_BORDER_COLOR="$COLOR_GREEN"
            CART_TITLE_STYLE="$BOLD_GREEN"
            CART_CATEGORY_STYLE="$COLOR_BRIGHT_GREEN"
            CART_CURSOR_COLOR="$BOLD_GREEN"
            CART_ITEM_STYLE="$COLOR_GREEN"
            CART_BASE_CATEGORY_STYLE="$COLOR_BRIGHT_GREEN"
            CART_BASE_ITEM_STYLE="$COLOR_GREEN"
            CART_REMOVE_HINT_STYLE="$COLOR_BRIGHT_GREEN"
            CART_COUNT_STYLE="$COLOR_BRIGHT_GREEN"
            
            INSTRUCTION_KEY_STYLE="$BOLD_GREEN"
            INSTRUCTION_TEXT_STYLE="$COLOR_GREEN"
            
            SUMMARY_BORDER_COLOR="$COLOR_GREEN"
            SUMMARY_TITLE_STYLE="$BOLD_GREEN"
            SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_GREEN"
            SUMMARY_CHECKMARK_COLOR="$BOLD_GREEN"
           
            STATUS_BORDER_COLOR="$COLOR_GREEN"
            STATUS_TITLE_STYLE="$BOLD_GREEN"
            STATUS_PENDING_STYLE="$COLOR_GREEN"
            STATUS_RUNNING_STYLE="$COLOR_BRIGHT_GREEN"
            STATUS_SUCCESS_STYLE="$BOLD_GREEN"
            STATUS_FAILED_STYLE="$COLOR_BRIGHT_GREEN"

            LOG_SUCCESS_STYLE="$BOLD_GREEN"
            LOG_WARNING_STYLE="$COLOR_BRIGHT_GREEN"
            LOG_INFO_STYLE="$COLOR_GREEN"
            ;;
            
        "ocean")
            # Ocean theme - blues and cyans
            GLOBAL_SEPARATOR_COLOR="$COLOR_CYAN"
            GLOBAL_TITLE_STYLE="$BOLD_CYAN"
            
            CATALOG_BORDER_COLOR="$COLOR_CYAN"
            CATALOG_TITLE_STYLE="$BOLD_CYAN"
            CATALOG_CATEGORY_STYLE="$COLOR_BRIGHT_BLUE"
            CATALOG_CURSOR_COLOR="$COLOR_BRIGHT_CYAN"
            CATALOG_ITEM_SELECTED_STYLE="$BOLD_CYAN"
            CATALOG_STATUS_IN_STACK_STYLE="$BOLD_CYAN"
            CATALOG_ICON_SELECTED_COLOR="$BOLD_CYAN"
            
            CART_BORDER_COLOR="$COLOR_BLUE"
            CART_TITLE_STYLE="$BOLD_BLUE"
            CART_CATEGORY_STYLE="$COLOR_BRIGHT_CYAN"
            CART_CURSOR_COLOR="$COLOR_BRIGHT_BLUE"
            CART_ITEM_STYLE="$COLOR_CYAN"
            CART_BASE_CATEGORY_STYLE="$COLOR_BRIGHT_CYAN"
            
            GLOBAL_HINT_STYLE="$COLOR_BRIGHT_CYAN"
            
            SUMMARY_BORDER_COLOR="$COLOR_CYAN"
            SUMMARY_TITLE_STYLE="$BOLD_CYAN"
            SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_BLUE"
            
            STATUS_BORDER_COLOR="$COLOR_CYAN"
            STATUS_TITLE_STYLE="$BOLD_CYAN"

            LOG_INFO_STYLE="$BOLD_BLUE"
            ;;
            
        "minimal")
            # Minimal theme - mostly white/gray
            GLOBAL_SEPARATOR_COLOR="$COLOR_GRAY"
            GLOBAL_TITLE_STYLE="$BOLD_WHITE"
            GLOBAL_HINT_STYLE="$COLOR_WHITE"
            
            CATALOG_BORDER_COLOR="$COLOR_GRAY"
            CATALOG_TITLE_STYLE="$BOLD_WHITE"
            CATALOG_CATEGORY_STYLE="$COLOR_WHITE"
            CATALOG_CURSOR_COLOR="$BOLD_WHITE"
            CATALOG_ITEM_SELECTED_STYLE="$BOLD_WHITE"
            CATALOG_ITEM_AVAILABLE_STYLE="$COLOR_WHITE"
            CATALOG_ITEM_DISABLED_STYLE="$COLOR_GRAY"
            CATALOG_STATUS_IN_STACK_STYLE="$BOLD_WHITE"
            CATALOG_STATUS_REQUIRED_STYLE="$COLOR_WHITE"
            CATALOG_PAGE_INDICATOR_STYLE="$COLOR_WHITE"
            CATALOG_ICON_SELECTED_COLOR="$BOLD_WHITE"
            CATALOG_ICON_AVAILABLE_COLOR="$COLOR_WHITE"
            CATALOG_ICON_DISABLED_COLOR="$COLOR_GRAY"
            CATALOG_ICON_WARNING_COLOR="$COLOR_WHITE"
            
            CART_BORDER_COLOR="$COLOR_GRAY"
            CART_TITLE_STYLE="$BOLD_WHITE"
            CART_CATEGORY_STYLE="$COLOR_WHITE"
            CART_CURSOR_COLOR="$BOLD_WHITE"
            CART_ITEM_STYLE="$COLOR_GRAY"
            CART_BASE_CATEGORY_STYLE="$COLOR_WHITE"
            CART_BASE_ITEM_STYLE="$COLOR_GRAY"
            CART_REMOVE_HINT_STYLE="$COLOR_WHITE"
            CART_COUNT_STYLE="$COLOR_WHITE"
            
            INSTRUCTION_KEY_STYLE="$BOLD_WHITE"
            INSTRUCTION_TEXT_STYLE="$COLOR_GRAY"
            
            SUMMARY_BORDER_COLOR="$COLOR_GRAY"
            SUMMARY_TITLE_STYLE="$BOLD_WHITE"
            SUMMARY_CATEGORY_STYLE="$COLOR_WHITE"
            SUMMARY_CHECKMARK_COLOR="$BOLD_WHITE"
           
            STATUS_BORDER_COLOR="$COLOR_GRAY"
            STATUS_TITLE_STYLE="$BOLD_WHITE"

            LOG_SUCCESS_STYLE="$BOLD_WHITE"
            LOG_WARNING_STYLE="$COLOR_WHITE"
            LOG_INFO_STYLE="$COLOR_GRAY"
            ;;
            
        "neon")
            # New neon theme - high contrast with bright colors
            GLOBAL_SEPARATOR_COLOR="$COLOR_BRIGHT_MAGENTA"
            GLOBAL_TITLE_STYLE="$BOLD_MAGENTA"
            GLOBAL_HINT_STYLE="$COLOR_BRIGHT_YELLOW"
            
            CATALOG_BORDER_COLOR="$COLOR_BRIGHT_CYAN"
            CATALOG_TITLE_STYLE="$BOLD_CYAN"
            CATALOG_CATEGORY_STYLE="$COLOR_BRIGHT_MAGENTA"
            CATALOG_CURSOR_COLOR="$COLOR_BRIGHT_YELLOW"
            CATALOG_ITEM_SELECTED_STYLE="$COLOR_BRIGHT_GREEN"
            CATALOG_ITEM_AVAILABLE_STYLE="$COLOR_BRIGHT_WHITE"
            CATALOG_ITEM_DISABLED_STYLE="$COLOR_GRAY"
            CATALOG_STATUS_IN_STACK_STYLE="$COLOR_BRIGHT_GREEN"
            CATALOG_STATUS_REQUIRED_STYLE="$COLOR_BRIGHT_YELLOW"
            CATALOG_ICON_SELECTED_COLOR="$COLOR_BRIGHT_GREEN"
            CATALOG_ICON_WARNING_COLOR="$COLOR_BRIGHT_YELLOW"
            
            CART_BORDER_COLOR="$COLOR_BRIGHT_MAGENTA"
            CART_TITLE_STYLE="$BOLD_MAGENTA"
            CART_CATEGORY_STYLE="$COLOR_BRIGHT_CYAN"
            CART_CURSOR_COLOR="$COLOR_BRIGHT_YELLOW"
            CART_ITEM_STYLE="$COLOR_BRIGHT_WHITE"
            CART_REMOVE_HINT_STYLE="$COLOR_BRIGHT_RED"
            CART_COUNT_STYLE="$COLOR_BRIGHT_YELLOW"
            
            INSTRUCTION_KEY_STYLE="$COLOR_BRIGHT_YELLOW"
            INSTRUCTION_TEXT_STYLE="$COLOR_BRIGHT_WHITE"
            
            SUMMARY_BORDER_COLOR="$COLOR_BRIGHT_MAGENTA"
            SUMMARY_TITLE_STYLE="$BOLD_MAGENTA"
            SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_CYAN"
            SUMMARY_CHECKMARK_COLOR="$COLOR_BRIGHT_GREEN"

            STATUS_BORDER_COLOR="$COLOR_BRIGHT_MAGENTA"
            STATUS_TITLE_STYLE="$BOLD_MAGENTA"
            ;;
            
        *)
            # Default theme - already set above
            ;;
    esac
}

# Load the selected theme
load_theme

# ============================================================================
# STYLING HELPER FUNCTIONS
# ============================================================================

# Style text with automatic reset
style_text() {
    local style="$1"
    local text="$2"
    printf "%b%s%b" "$style" "$text" "$STYLE_RESET"
}

# Print styled line with newline
style_line() {
    local style="$1"
    local text="$2"
    echo -e "${style}${text}${STYLE_RESET}"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Logging functions with themed output
log() { 
    local message="$1"
    local style="${2:-$LOG_DEFAULT_STYLE}"
    echo -e "${style}${message}${STYLE_RESET}"
}

error() { 
    log "Error: $1" "$LOG_ERROR_STYLE"
    exit 1
}

success() { 
    log "$1" "$LOG_SUCCESS_STYLE"
}

info() { 
    log "$1" "$LOG_INFO_STYLE"
}

warning() {
    log "$1" "$LOG_WARNING_STYLE"
}

# Check prerequisites
check_deps() {
    local deps=("docker" "kubectl" "colima")
    for dep in "${deps[@]}"; do
        command -v "$dep" &> /dev/null || error "$dep is not installed or not in PATH"
    done
}

# Check if Nexus is available
check_nexus() {
    if curl -s http://localhost:8081 > /dev/null 2>&1; then
        success "${ICON_SUCCESS} Nexus detected at http://localhost:8081"
        return 0
    fi
    return 1
}

# Generate SSH host keys if they don't exist
generate_ssh_host_keys() {
    mkdir -p "$SSH_KEYS_DIR"
    
    # Generate keys if they don't exist
    if [ ! -f "$SSH_KEYS_DIR/ssh_host_rsa_key" ]; then
        log "Generating SSH host keys..."
        ssh-keygen -q -t rsa -b 4096 -f "$SSH_KEYS_DIR/ssh_host_rsa_key" -N "" -C "ai-devkit-rsa" >/dev/null 2>&1
        ssh-keygen -q -t ecdsa -b 521 -f "$SSH_KEYS_DIR/ssh_host_ecdsa_key" -N "" -C "ai-devkit-ecdsa" >/dev/null 2>&1
        ssh-keygen -q -t ed25519 -f "$SSH_KEYS_DIR/ssh_host_ed25519_key" -N "" -C "ai-devkit-ed25519" >/dev/null 2>&1
        success "SSH host keys generated"
    else
        success "Using existing SSH host keys"
    fi
}

# Create SSH host keys secret
create_ssh_host_keys_secret() {
    # Delete existing secret if it exists
    kubectl delete secret ssh-host-keys -n ${NAMESPACE} --ignore-not-found=true >/dev/null 2>&1
    
    # Create secret from files
    kubectl create secret generic ssh-host-keys -n ${NAMESPACE} \
        --from-file=ssh_host_rsa_key="$SSH_KEYS_DIR/ssh_host_rsa_key" \
        --from-file=ssh_host_rsa_key.pub="$SSH_KEYS_DIR/ssh_host_rsa_key.pub" \
        --from-file=ssh_host_ecdsa_key="$SSH_KEYS_DIR/ssh_host_ecdsa_key" \
        --from-file=ssh_host_ecdsa_key.pub="$SSH_KEYS_DIR/ssh_host_ecdsa_key.pub" \
        --from-file=ssh_host_ed25519_key="$SSH_KEYS_DIR/ssh_host_ed25519_key" \
        --from-file=ssh_host_ed25519_key.pub="$SSH_KEYS_DIR/ssh_host_ed25519_key.pub" >/dev/null 2>&1
}

# Parse YAML file (simple parser using sed/awk)
# This is a basic parser - in production you might want to use yq or python
parse_yaml() {
    local file=$1
    local prefix=$2
    
    # Read the file and convert YAML to shell variables
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" $file |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'", vn, $2, $3);
        }
    }'
}

# Load component data from YAML files
load_components() {
    local components=()
    local categories=()
    local category_names=()
    local category_descriptions=()
    local category_orders=()
    
    # Check if components directory exists
    [[ ! -d "$COMPONENTS_DIR" ]] && error "Components directory '$COMPONENTS_DIR' not found"
    
    # Discover categories (subdirectories)
    for category_dir in "$COMPONENTS_DIR"/*; do
        [[ ! -d "$category_dir" ]] && continue
        
        local category_name=$(basename "$category_dir")
        local display_name="$category_name"
        local description=""
        local order=999
        
        # Load category metadata if exists
        if [[ -f "$category_dir/.category.yaml" ]]; then
            eval $(parse_yaml "$category_dir/.category.yaml" "cat_")
            
            [[ -n "$cat_display_name" ]] && display_name="$cat_display_name"
            [[ -n "$cat_description" ]] && description="$cat_description"
            [[ -n "$cat_order" ]] && order="$cat_order"
            
            # Clear variables for next iteration
            unset cat_display_name cat_description cat_order
        fi
        
        categories+=("$category_name")
        category_names+=("$display_name")
        category_descriptions+=("$description")
        category_orders+=("$order")
    done
    
    # Sort categories by order
    # This is a simple bubble sort - good enough for small arrays
    local n=${#categories[@]}
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if [[ ${category_orders[$j]} -gt ${category_orders[$((j+1))]} ]]; then
                # Swap
                local temp="${categories[$j]}"
                categories[$j]="${categories[$((j+1))]}"
                categories[$((j+1))]="$temp"
                
                temp="${category_names[$j]}"
                category_names[$j]="${category_names[$((j+1))]}"
                category_names[$((j+1))]="$temp"
                
                temp="${category_descriptions[$j]}"
                category_descriptions[$j]="${category_descriptions[$((j+1))]}"
                category_descriptions[$((j+1))]="$temp"
                
                temp="${category_orders[$j]}"
                category_orders[$j]="${category_orders[$((j+1))]}"
                category_orders[$((j+1))]="$temp"
            fi
        done
    done
    
    # Output categories and their display names properly
    echo "${categories[@]}"
    echo "---SEPARATOR---"
    # Output category names one per line to preserve spaces
    for cat_name in "${category_names[@]}"; do
        echo "$cat_name"
    done
    echo "---SEPARATOR---"
    
    # Load components from each category
    for category in "${categories[@]}"; do
        for yaml_file in "$COMPONENTS_DIR/$category"/*.yaml; do
            [[ ! -f "$yaml_file" ]] && continue
            [[ "$yaml_file" == *"/.category.yaml" ]] && continue
            
            # Parse the YAML file
            eval $(parse_yaml "$yaml_file" "comp_")
            
            # Output component data
            echo "${comp_id}|${comp_name}|${comp_group}|${comp_requires}|${category}|${yaml_file}"
            
            # Clear component variables for next iteration
            unset comp_id comp_name comp_group comp_requires
        done
    done
}

# ============================================================================
# UI DRAWING FUNCTIONS
# ============================================================================

# Function to draw a box with optional title and bottom text
draw_box() {
    local x=$1 y=$2 width=$3 height=$4 title=$5 bottom_text=$6 
    local border_color="${7:-$CATALOG_BORDER_COLOR}"  # Allow custom border color
    local title_style="${8:-$CATALOG_TITLE_STYLE}"    # Allow custom title style
    
    tput cup $y $x
    printf "%b%s%b" "$border_color" "$BOX_TOP_LEFT" "$STYLE_RESET"
    for ((i=0; i<width-2; i++)); do 
        printf "%b%s%b" "$border_color" "$BOX_HORIZONTAL" "$STYLE_RESET"
    done
    printf "%b%s%b" "$border_color" "$BOX_TOP_RIGHT" "$STYLE_RESET"
    
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local title_pos=$(( (width - title_len - 2) / 2 ))
        tput cup $y $((x + title_pos))
        printf "%b%s%b %b%s%b %b%s%b" \
            "$border_color" "$BOX_TITLE_LEFT" "$STYLE_RESET" \
            "$title_style" "$title" "$STYLE_RESET" \
            "$border_color" "$BOX_TITLE_RIGHT" "$STYLE_RESET"
    fi
    
    for ((i=1; i<height-1; i++)); do
        tput cup $((y + i)) $x
        printf "%b%s%b" "$border_color" "$BOX_VERTICAL" "$STYLE_RESET"
        tput cup $((y + i)) $((x + width - 1))
        printf "%b%s%b" "$border_color" "$BOX_VERTICAL" "$STYLE_RESET"
    done
    
    tput cup $((y + height - 1)) $x
    printf "%b%s%b" "$border_color" "$BOX_BOTTOM_LEFT" "$STYLE_RESET"
    
    if [[ -n "$bottom_text" ]]; then
        local text_len=${#bottom_text}
        local center_pos=$(( (width - text_len - 4) / 2 ))
        local page_style="${9:-$CATALOG_PAGE_INDICATOR_STYLE}"
        
        for ((i=0; i<center_pos; i++)); do 
            printf "%b%s%b" "$border_color" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
        printf " %b%s%b " "$page_style" "$bottom_text" "$STYLE_RESET"
        for ((i=0; i<width-center_pos-text_len-6; i++)); do 
            printf "%b%s%b" "$border_color" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
    else
        for ((i=0; i<width-2; i++)); do 
            printf "%b%s%b" "$border_color" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
    fi
    
    printf "%b%s%b" "$border_color" "$BOX_BOTTOM_RIGHT" "$STYLE_RESET"
}

# Function to draw a horizontal separator line
draw_separator() {
    local width=$1
    local y=$2
    local color="${3:-$GLOBAL_SEPARATOR_COLOR}"
    
    tput cup $y 0
    for ((i=0; i<width; i++)); do 
        printf "%b%s%b" "$color" "$BOX_SEPARATOR" "$STYLE_RESET"
    done
}

# Function to center text on a line
print_centered() {
    local text=$1
    local width=$2
    local y=$3
    local style=$4
    
    local text_len=${#text}
    local x=$(( (width - text_len) / 2 ))
    
    tput cup $y $x
    printf "%b%s%b" "$style" "$text" "$STYLE_RESET"
}

# Function to draw the gradient title bar
draw_gradient_title() {
    local title="${1:-AI DevKit Pod Configurator}"  # Default title if none provided
    local row="${2:-1}"  # Default to row 1
    
    local term_width=$(tput cols)
    local title_len=${#title}
    local padding_each_side=$(( (term_width - title_len - 2) / 2 ))
    local extra_padding=$(( (term_width - title_len - 2) % 2 ))
    
    # Create gradient array
    local gradient_colors=("$COLOR_CYAN" "$COLOR_BLUE" "$COLOR_LAVENDER" "$COLOR_MAGENTA")
    local gradient_len=${#gradient_colors[@]}
    
    # Move cursor to specified row
    tput cup $row 0
    
    # Left side with gradient using vertical bars
    for ((i=0; i<padding_each_side; i++)); do
        local color_idx=$((i * gradient_len / padding_each_side))
        [[ $color_idx -ge $gradient_len ]] && color_idx=$((gradient_len - 1))
        printf "%b%s" "${gradient_colors[$color_idx]}" "$BOX_VERTICAL"
    done
    
    # Title
    printf " %b%s%b " "$BOLD_WHITE" "$title" "$STYLE_RESET"
    
    # Right side with reverse gradient using vertical bars
    for ((i=padding_each_side+extra_padding; i>0; i--)); do
        local color_idx=$((i * gradient_len / (padding_each_side + extra_padding)))
        [[ $color_idx -ge $gradient_len ]] && color_idx=$((gradient_len - 1))
        printf "%b%s" "${gradient_colors[$color_idx]}" "$BOX_VERTICAL"
    done
    printf "%b\n" "$STYLE_RESET"
}

# Function to render all deployment steps
render_deployment_steps() {
    local col=$1
    local width=$2
    local steps=("${!3}")
    local statuses=("${!4}")
    local messages=("${!5}")
    
    local row=5
    
    # Clear the status area first
    for ((r=5; r<25; r++)); do
        tput cup $r $((col + 2))
        printf "%-$((width-4))s" " "
    done
    
    # Render each step
    for i in "${!steps[@]}"; do
        tput cup $row $((col + 2))
        
        local icon=""
        local icon_style=""
        
        case "${statuses[$i]}" in
            "pending")
                icon="$ICON_PENDING"
                icon_style="$STATUS_PENDING_STYLE"
                ;;
            "running")
                icon="$ICON_PENDING"
                icon_style="$STATUS_RUNNING_STYLE"
                ;;
            "success")
                icon="$ICON_SUCCESS"
                icon_style="$STATUS_SUCCESS_STYLE"
                ;;
            "failed")
                icon="$ICON_FAILED"
                icon_style="$STATUS_FAILED_STYLE"
                ;;
        esac
        
        printf "%b%s%b %b%s%b" "$icon_style" "$icon" "$STYLE_RESET" "$STATUS_STEP_STYLE" "${steps[$i]}" "$STYLE_RESET"
        
        # Add message if exists
        if [[ -n "${messages[$i]}" ]]; then
            ((row++))
            tput cup $row $((col + 4))
            printf "%b%s%b" "$STATUS_INFO_STYLE" "${messages[$i]}" "$STYLE_RESET"
        fi
        
        ((row+=2))
    done
    
    # Use a global variable to pass the row value back
    DEPLOYMENT_STATUS_FINAL_ROW=$row
}

# Function to update a specific deployment step
update_deployment_step() {
    local step_index=$1
    local status=$2
    local message="${3:-}"
    local statuses_var=$4
    local messages_var=$5
    
    # Update the arrays
    eval "${statuses_var}[$step_index]=\"$status\""
    eval "${messages_var}[$step_index]=\"$message\""
}

# Function to show connection details
show_connection_details() {
    local row=$1
    local col=$2
    local width=$3
    local pod_name=$4
    local port_forward_pid=$5
    local claude_selected=$6
    
    ((row+=2))
    tput cup $row $((col + 2))
    printf "%b%s%b" "$STATUS_INFO_STYLE" "Connection Details:" "$STYLE_RESET"
    ((row+=2))
    
    tput cup $row $((col + 4))
    printf "%bSSH:%b devuser@localhost -p 2222" "$BOLD_WHITE" "$STYLE_RESET"
    ((row++))
    
    tput cup $row $((col + 4))
    printf "%bPassword:%b devuser" "$BOLD_WHITE" "$STYLE_RESET"
    ((row+=2))
    
    tput cup $row $((col + 4))
    printf "%bFile Manager:%b" "$BOLD_WHITE" "$STYLE_RESET"
    ((row++))
    
    tput cup $row $((col + 4))
    printf "http://localhost:8090"
    ((row++))
    
    tput cup $row $((col + 4))
    printf "(admin/admin)"
    ((row+=2))
    
    if [[ $claude_selected == true ]]; then
        tput cup $row $((col + 4))
        printf "%bClaude Code:%b claude" "$BOLD_WHITE" "$STYLE_RESET"
        ((row+=2))
    fi
    
    tput cup $row $((col + 4))
    printf "%bPort Forward PID:%b $port_forward_pid" "$BOLD_WHITE" "$STYLE_RESET"
}

# Function to check if a group has items in cart
has_group_in_cart() {
    local check_group=$1
    shift
    local groups=("$@")
    shift $((${#groups[@]} / 2))
    local in_cart=("$@")
    
    for j in "${!groups[@]}"; do
        [[ "${groups[$j]}" == "$check_group" && "${in_cart[$j]}" == true ]] && return 0
    done
    return 1
}

# Check if requirements are met
requirements_met() {
    local item_requires=$1
    shift
    local groups=("$@")
    local half=$((${#groups[@]} / 2))
    local in_cart=("${groups[@]:$half}")
    groups=("${groups[@]:0:$half}")
    
    [[ -z "$item_requires" ]] && return 0
    [[ "$item_requires" == "[]" ]] && return 0
    
    # Split by space for multiple requirements
    for req in $item_requires; do
        has_group_in_cart "$req" "${groups[@]}" "${in_cart[@]}" || return 1
    done
    return 0
}

# Function to get display name for category
get_category_display_name() {
    local cat=$1
    local categories=("${!2}")
    local category_names=("${!3}")
    
    for i in "${!categories[@]}"; do
        if [[ "${categories[$i]}" == "$cat" ]]; then
            echo "${category_names[$i]}"
            return
        fi
    done
    echo "$cat"
}

# Function to add/remove item from cart (fixed for Bash 3.2+)
toggle_cart_item() {
    local index=$1
    local action=$2
    local ids_array_name=$3
    local names_array_name=$4
    local groups_array_name=$5
    local requires_array_name=$6
    local in_cart_array_name=$7
    local hint_msg_var=$8
    local hint_timer_var=$9
    
    # Get arrays by reference
    eval "local ids=(\"\${${ids_array_name}[@]}\")"
    eval "local names=(\"\${${names_array_name}[@]}\")"
    eval "local groups=(\"\${${groups_array_name}[@]}\")"
    eval "local requires=(\"\${${requires_array_name}[@]}\")"
    eval "local in_cart=(\"\${${in_cart_array_name}[@]}\")"
    
    # Bounds checking
    if [[ $index -lt 0 ]] || [[ $index -ge ${#ids[@]} ]]; then
        return 1
    fi
    
    if [[ "$action" == "add" ]]; then
        # Check requirements
        if [[ -n "${requires[$index]}" ]] && [[ "${requires[$index]}" != "[]" ]]; then
            if ! requirements_met "${requires[$index]}" "${groups[@]}" "${in_cart[@]}"; then
                eval "${hint_msg_var}='${ICON_WARNING}  Requires: ${requires[$index]}'"
                eval "${hint_timer_var}=30"
                return 1
            fi
        fi
        
        # Handle mutually exclusive groups
        for j in "${!groups[@]}"; do
            if [[ "${groups[$j]}" == "${groups[$index]}" ]] && [[ $j -ne $index ]] && [[ "${in_cart[$j]}" == true ]]; then
                eval "${in_cart_array_name}[$j]=false"
                eval "${hint_msg_var}='${ICON_INFO}  Replaced ${names[$j]} with ${names[$index]}'"
                eval "${hint_timer_var}=30"
            fi
        done
        
        eval "${in_cart_array_name}[$index]=true"
        local msg=$(eval "echo \$${hint_msg_var}")
        [[ -z "$msg" ]] && eval "${hint_msg_var}='${ICON_SUCCESS} Added ${names[$index]} to stack'" && eval "${hint_timer_var}=20"
    else
        eval "${in_cart_array_name}[$index]=false"
        
        # Check for dependent items
        local removed_group="${groups[$index]}"
        local dependents=""
        
        for j in "${!requires[@]}"; do
            [[ -z "${requires[$j]}" ]] && continue
            
            # Check if this item depends on the removed group
            if [[ "${requires[$j]}" == *"$removed_group"* ]] && [[ "${in_cart[$j]}" == true ]]; then
                # Double-check this is the only item providing the requirement
                local still_has_provider=false
                for k in "${!groups[@]}"; do
                    if [[ $k -ne $index ]] && [[ "${groups[$k]}" == "$removed_group" ]] && [[ "${in_cart[$k]}" == true ]]; then
                        still_has_provider=true
                        break
                    fi
                done
                
                if [[ $still_has_provider == false ]]; then
                    eval "${in_cart_array_name}[$j]=false"
                    [[ -n "$dependents" ]] && dependents+=", "
                    dependents+="${names[$j]}"
                fi
            fi
        done
        
        if [[ -n "$dependents" ]]; then
            eval "${hint_msg_var}='${ICON_WARNING}  Also removed dependent items: $dependents'"
            eval "${hint_timer_var}=40"
        else
            eval "${hint_msg_var}='${ICON_SUCCESS} Removed ${names[$index]} from cart'"
            eval "${hint_timer_var}=20"
        fi
    fi
}

# Calculate pagination boundaries for catalog
calculate_pagination() {
    local total_items=$1
    local content_height=$2
    local component_categories=("${!3}")
    local page_boundaries_var=$4
    
    eval "$page_boundaries_var=(0)"
    
    local current_page_rows=0
    local last_category=""
    
    for idx in $(seq 0 $((total_items - 1))); do
        local item_category="${component_categories[$idx]}"
        
        # Count category header row if this is a new category
        if [[ "$item_category" != "$last_category" ]]; then
            ((current_page_rows++))
            last_category="$item_category"
        fi
        
        # Count the item row
        ((current_page_rows++))
        
        # Check if we've exceeded the page height
        if [[ $current_page_rows -gt $((content_height - 2)) ]]; then
            eval "$page_boundaries_var+=($idx)"
            current_page_rows=1
            
            # Also need to count its category header if different
            if [[ $idx -gt 0 ]]; then
                local prev_category="${component_categories[$((idx-1))]}"
                if [[ "$item_category" != "$prev_category" ]]; then
                    ((current_page_rows++))
                fi
            fi
            last_category="$item_category"
        fi
    done
}

# Function to get screen row for item
get_screen_row_for_item() {
    local target_idx=$1
    local catalog_first_visible=$2
    local catalog_last_visible=$3
    local component_categories=("${!4}")
    
    local row=5  # Changed from 4 to account for spacing
    local prev_category=""
    
    for ((idx=$catalog_first_visible; idx<=$catalog_last_visible && idx<=$target_idx; idx++)); do
        local item_category="${component_categories[$idx]}"
        
        if [[ "$item_category" != "$prev_category" ]]; then
            prev_category="$item_category"
            ((row++))
        fi
        
        if [[ $idx -eq $target_idx ]]; then
            echo $row
            return
        fi
        ((row++))
    done
}

# Function to render catalog items for current page
render_catalog() {
    # Parameters passed as positional arguments
    local catalog_page=$1
    local page_boundaries_var=$2
    local total_items=$3
    local content_height=$4
    local catalog_width=$5
    local view=$6
    local current=$7
    shift 7
    
    # Arrays passed by name
    local ids_array_name=$1
    local names_array_name=$2
    local groups_array_name=$3
    local requires_array_name=$4
    local component_categories_array_name=$5
    local in_cart_array_name=$6
    local categories_array_name=$7
    local category_names_array_name=$8
    local catalog_first_visible_var=$9
    local catalog_last_visible_var=${10}
    
    # Get arrays by reference
    eval "local ids=(\"\${${ids_array_name}[@]}\")"
    eval "local names=(\"\${${names_array_name}[@]}\")"
    eval "local groups=(\"\${${groups_array_name}[@]}\")"
    eval "local requires=(\"\${${requires_array_name}[@]}\")"
    eval "local component_categories=(\"\${${component_categories_array_name}[@]}\")"
    eval "local in_cart=(\"\${${in_cart_array_name}[@]}\")"
    eval "local categories=(\"\${${categories_array_name}[@]}\")"
    eval "local category_names=(\"\${${category_names_array_name}[@]}\")"
    
    # Get page boundaries array
    eval "local page_boundaries=(\"\${${page_boundaries_var}[@]}\")"
    
    local start_idx=${page_boundaries[$catalog_page]}
    local end_idx=$total_items
    
    if [[ $((catalog_page + 1)) -lt ${#page_boundaries[@]} ]]; then
        end_idx=${page_boundaries[$((catalog_page + 1))]}
    fi
    
    local display_row=4
    local last_category=""
    local first_visible_idx=-1
    local last_visible_idx=-1
    
    # Clear catalog area
    for ((row=4; row<content_height+4; row++)); do
        tput cup $row 0
        printf "%b%s%b" "$CATALOG_BORDER_COLOR" "$BOX_VERTICAL" "$STYLE_RESET"
        for ((col=1; col<catalog_width-1; col++)); do
            printf " "
        done
        printf "%b%s%b" "$CATALOG_BORDER_COLOR" "$BOX_VERTICAL" "$STYLE_RESET"
    done
    
    display_row=5
    last_category=""
    
    for ((idx=start_idx; idx<end_idx; idx++)); do
        [[ $display_row -ge $((content_height + 4)) ]] && break
        
        local item_category="${component_categories[$idx]}"
        local display_name=$(get_category_display_name "$item_category" categories[@] category_names[@])
        
        # Category headers
        if [[ "$item_category" != "$last_category" ]]; then
            tput cup $display_row 2
            printf "%b%s%b" "$CATALOG_CATEGORY_STYLE" "$display_name" "$STYLE_RESET"
            last_category="$item_category"
            ((display_row++))
            [[ $display_row -ge $((content_height + 4)) ]] && break
        fi
        
        # Render item with proper indentation
        if [[ $display_row -lt $((content_height + 4)) ]]; then
            [[ $first_visible_idx -eq -1 ]] && first_visible_idx=$idx
            last_visible_idx=$idx
            
            tput cup $display_row 2
            
            # Cursor
            if [[ $view == "catalog" && $idx -eq $current ]]; then
                printf "%b%s%b " "$CATALOG_CURSOR_COLOR" "$ICON_CURSOR" "$STYLE_RESET"
            else
                printf "  "
            fi
            
            # Check availability
            local available=true status="" status_color=""
            
            if [[ "${in_cart[$idx]}" == true ]]; then
                printf "%b%s%b " "$CATALOG_ICON_SELECTED_COLOR" "$ICON_SELECTED" "$STYLE_RESET"
                status="(in stack)"
                status_color="$CATALOG_STATUS_IN_STACK_STYLE"
            elif has_group_in_cart "${groups[$idx]}" "${groups[@]}" "${in_cart[@]}"; then
                printf "%b%s%b " "$CATALOG_ICON_DISABLED_COLOR" "$ICON_DISABLED" "$STYLE_RESET"
                available=false
            elif [[ -n "${requires[$idx]}" ]] && [[ "${requires[$idx]}" != "[]" ]] && ! requirements_met "${requires[$idx]}" "${groups[@]}" "${in_cart[@]}"; then
                printf "%b%s%b " "$CATALOG_ICON_WARNING_COLOR" "$ICON_AVAILABLE" "$STYLE_RESET"
                status="* ${requires[$idx]} required"
                status_color="$CATALOG_STATUS_REQUIRED_STYLE"
            else
                printf "%b%s%b " "$CATALOG_ICON_AVAILABLE_COLOR" "$ICON_AVAILABLE" "$STYLE_RESET"
            fi
            
            # Item name
            if [[ $available == true || "${in_cart[$idx]}" == true ]]; then
                printf "%b%s%b" "$CATALOG_ITEM_AVAILABLE_STYLE" "${names[$idx]}" "$STYLE_RESET"
            else
                printf "%b%s%b" "$CATALOG_ITEM_DISABLED_STYLE" "${names[$idx]}" "$STYLE_RESET"
            fi
            
            # Status
            if [[ -n "$status" ]]; then
                local name_len=${#names[$idx]}
                local status_len=${#status}
                local padding=$((catalog_width - name_len - status_len - 8))
                if [[ $padding -gt 0 ]]; then
                    tput cuf $padding
                    printf "%b%s%b" "$status_color" "$status" "$STYLE_RESET"
                fi
            fi
            
            ((display_row++))
        fi
    done
    
    # Update the variables properly
    eval "${catalog_first_visible_var}=${first_visible_idx}"
    eval "${catalog_last_visible_var}=${last_visible_idx}"
    
    # Page indicator
    local total_pages=${#page_boundaries[@]}
    if [[ $total_pages -gt 1 ]]; then
        local page_text="Page $((catalog_page + 1))/$total_pages"
        local text_len=${#page_text}
        local center_pos=$(( (catalog_width - text_len - 4) / 2 ))
        
        tput cup $((content_height + 4)) 0
        printf "%b%s%b" "$CATALOG_BORDER_COLOR" "$BOX_BOTTOM_LEFT" "$STYLE_RESET"
        
        for ((i=0; i<center_pos; i++)); do 
            printf "%b%s%b" "$CATALOG_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
        printf " %b%s%b " "$CATALOG_PAGE_INDICATOR_STYLE" "$page_text" "$STYLE_RESET"
        
        local remaining=$((catalog_width - center_pos - text_len - 4))
        for ((i=0; i<remaining; i++)); do 
            printf "%b%s%b" "$CATALOG_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
        
        printf "%b%s%b" "$CATALOG_BORDER_COLOR" "$BOX_BOTTOM_RIGHT" "$STYLE_RESET"
    fi
}

# Function to render cart items
render_cart() {
    local cart_start_col=$1
    local cart_width=$2
    local content_height=$3
    local view=$4
    local cart_cursor=$5
    shift 5
    
    # Get arrays by name and dereference them
    local in_cart_array_name=$1
    local ids_array_name=$2
    local names_array_name=$3
    local component_categories_array_name=$4
    local categories_array_name=$5
    local category_names_array_name=$6
    
    # Get arrays by reference
    eval "local in_cart=(\"\${${in_cart_array_name}[@]}\")"
    eval "local ids=(\"\${${ids_array_name}[@]}\")"
    eval "local names=(\"\${${names_array_name}[@]}\")"
    eval "local component_categories=(\"\${${component_categories_array_name}[@]}\")"
    eval "local categories=(\"\${${categories_array_name}[@]}\")"
    eval "local category_names=(\"\${${category_names_array_name}[@]}\")"
    
    local display_row=4
    local cart_items_array=()
    
    # Collect cart items
    for idx in "${!in_cart[@]}"; do
        [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
    done
    
    local cart_count=${#cart_items_array[@]}
    
    # Clear cart area
    for ((row=4; row<content_height+4; row++)); do
        tput cup $row $((cart_start_col + 1))
        printf "%-$((cart_width-2))s" " "
    done
    
    # Start content one row down for spacing
    display_row=5
    tput cup $display_row $((cart_start_col + 1))
    
    # Show base components first
    tput cup $display_row $((cart_start_col + 2))
    printf "%b%s%b" "$CART_BASE_CATEGORY_STYLE" "Base Development Tools" "$STYLE_RESET"
    ((display_row++))
    
    # Base components list with checkmarks
    local base_components=(
        "Filebrowser (port 8090)"
        "Git"
        "GitHub CLI (gh)"
        "Microsoft TUI Test"
        "Node.js 20.18.0"
        "SSH Server (port 2222)"
    )
    
    for base_comp in "${base_components[@]}"; do
        if [[ $display_row -lt $((content_height + 4)) ]]; then
            tput cup $display_row $((cart_start_col + 4))
            printf "%b%s%b %s" "$SUMMARY_CHECKMARK_COLOR" "$ICON_CHECKMARK" "$STYLE_RESET" "$base_comp"
            ((display_row++))
        fi
    done
    
    if [[ $cart_count -gt 0 ]]; then
        # Group items by category
        local cart_display_count=0
        local last_category=""
        
        for cat_idx in "${!categories[@]}"; do
            local category="${categories[$cat_idx]}"
            local category_display="${category_names[$cat_idx]}"
            local category_has_items=false
            
            for idx in "${cart_items_array[@]}"; do
                if [[ "${component_categories[$idx]}" == "$category" ]]; then
                    if [[ $category_has_items == false ]]; then
                        ((display_row++))
                        if [[ $display_row -lt $((content_height + 4)) ]]; then
                            tput cup $display_row $((cart_start_col + 2))
                            printf "%b%s%b" "$CART_CATEGORY_STYLE" "$category_display" "$STYLE_RESET"
                            ((display_row++))
                            category_has_items=true
                        fi
                    fi
                    
                    if [[ $display_row -lt $((content_height + 4)) ]]; then
                        tput cup $display_row $((cart_start_col + 2))
                        
                        # Cursor
                        if [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]]; then
                            printf "%b%s%b " "$CART_CURSOR_COLOR" "$ICON_CURSOR" "$STYLE_RESET"
                        else
                            printf "  "
                        fi
                        
                        # Checkmark instead of bullet
                        printf "%b%s%b %b%s%b" "$SUMMARY_CHECKMARK_COLOR" "$ICON_CHECKMARK" "$STYLE_RESET" "$CART_ITEM_STYLE" "${names[$idx]}" "$STYLE_RESET"
                        
                        # Remove hint
                        if [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]]; then
                            printf " %b[DEL to remove]%b" "$CART_REMOVE_HINT_STYLE" "$STYLE_RESET"
                        fi
                        
                        ((display_row++))
                    fi
                    ((cart_display_count++))
                fi
            done
        done
    fi
    
    # Update the Build Stack box to show count in footer
    local bottom_text=""
    if [[ $cart_count -gt 0 ]]; then
        if [[ $cart_count -eq 1 ]]; then
            bottom_text="1 selected"
        else
            bottom_text="$cart_count selected"
        fi
    fi
    
    # Redraw the Build Stack box bottom border with the count
    if [[ -n "$bottom_text" ]]; then
        local x=$cart_start_col
        local y=$((content_height + 4))
        local width=$cart_width
        
        tput cup $y $x
        printf "%b%s%b" "$CART_BORDER_COLOR" "$BOX_BOTTOM_LEFT" "$STYLE_RESET"
        
        local text_len=${#bottom_text}
        local center_pos=$(( (width - text_len - 4) / 2 ))
        
        for ((i=0; i<center_pos; i++)); do 
            printf "%b%s%b" "$CART_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
        printf " %b%s%b " "$CART_COUNT_STYLE" "$bottom_text" "$STYLE_RESET"
        
        local remaining=$((width - center_pos - text_len - 4))
        for ((i=0; i<remaining; i++)); do 
            printf "%b%s%b" "$CART_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
        
        printf "%b%s%b" "$CART_BORDER_COLOR" "$BOX_BOTTOM_RIGHT" "$STYLE_RESET"
    fi
}

# Main component selection UI function (renamed from select_components)
run_component_selection_ui() {
    set +e  # Do not exit on error
    
    # Load components data
    local component_data=$(load_components)
    
    # Split the data
    local categories_line=$(echo "$component_data" | sed -n '1p')
    local components_data=""
    local category_names=()
    
    # Read data line by line
    local reading_names=false
    local reading_components=false
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        if [[ $line_num -eq 1 ]]; then
            # First line is categories
            continue
        elif [[ "$line" == "---SEPARATOR---" ]]; then
            if [[ $reading_names == false ]]; then
                reading_names=true
            else
                reading_names=false
                reading_components=true
            fi
            continue
        fi
        
        if [[ $reading_names == true ]]; then
            category_names+=("$line")
        elif [[ $reading_components == true ]]; then
            components_data+="$line"$NL
        fi
    done <<< "$component_data"
    
    # Convert categories to array
    IFS=' ' read -ra categories <<< "$categories_line"
    
    # Parse components
    local ids=() names=() groups=() requires=() component_categories=() yaml_files=() in_cart=()
    
    while IFS='|' read -r id name group req category yaml_file; do
        [[ -z "$id" ]] && continue
        ids+=("$id")
        names+=("$name")
        groups+=("$group")
        requires+=("$req")
        component_categories+=("$category")
        yaml_files+=("$yaml_file")
        in_cart+=(false)
    done <<< "$components_data"
    
    local current=0 view="catalog" cart_cursor=0
    local total_items=${#ids[@]}
    local hint_message="" hint_timer=0
    local catalog_first_visible=0 catalog_last_visible=0
    local position_cursor_after_render=""
    
    # Terminal dimensions and pagination
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local catalog_width=$((term_width / 2 - 2))
    local cart_start_col=$((catalog_width + 3))
    local cart_width=$((term_width - cart_start_col))
    local content_height=$((term_height - 7))
    local catalog_page=0 cart_page=0

    # Calculate pagination
    local page_boundaries=()
    calculate_pagination $total_items $content_height component_categories[@] page_boundaries
    
    local total_pages=${#page_boundaries[@]}
    
    # Hide cursor and disable echo
    tput civis
    stty -echo
    trap 'tput cnorm; stty echo' EXIT
    
    # Saved screen state
    local last_current=-1 last_cart_cursor=-1 last_view="" last_catalog_page=-1 last_cart_page=-1
    local screen_initialized=false
    local force_cart_update=false
    local force_catalog_update=false
    
    # Main display loop
    while true; do
        # Initialize screen if needed
        if [[ $screen_initialized == false ]]; then
            clear
            draw_gradient_title "AI DevKit Pod Configurator" 1 
            echo ""
            draw_box 0 3 $catalog_width $((content_height + 2)) "Available Components" "" "$CATALOG_BORDER_COLOR" "$CATALOG_TITLE_STYLE"
            draw_box $cart_start_col 3 $cart_width $((content_height + 2)) "Build Stack" "" "$CART_BORDER_COLOR" "$CART_TITLE_STYLE" 
            screen_initialized=true
        fi
        
        # Handle catalog rendering
        if [[ -n "$position_cursor_after_render" ]]; then
            render_catalog $catalog_page page_boundaries $total_items $content_height $catalog_width \
                          $view $current ids names groups requires component_categories \
                          in_cart categories category_names catalog_first_visible catalog_last_visible

            if [[ "$position_cursor_after_render" == "first" ]]; then
                current=$catalog_first_visible
            elif [[ "$position_cursor_after_render" == "last" ]]; then
                current=$catalog_last_visible
            fi
            position_cursor_after_render=""
            
            render_catalog $catalog_page page_boundaries $total_items $content_height $catalog_width \
                          $view $current ids names groups requires component_categories \
                          in_cart categories category_names catalog_first_visible catalog_last_visible

            last_catalog_page=$catalog_page
            last_current=$current
        elif [[ $last_catalog_page != $catalog_page || $last_view != $view || $force_catalog_update == true ]]; then
            render_catalog $catalog_page page_boundaries $total_items $content_height $catalog_width \
                          $view $current ids names groups requires component_categories \
                          in_cart categories category_names catalog_first_visible catalog_last_visible

            last_catalog_page=$catalog_page
            force_catalog_update=false
        elif [[ $last_current != $current && $view == "catalog" ]]; then
            # Optimized cursor movement
            if [[ $current -ge $catalog_first_visible && $current -le $catalog_last_visible && 
                  $last_current -ge $catalog_first_visible && $last_current -le $catalog_last_visible ]]; then
                
                # Update cursor positions
                local old_screen_row=$(get_screen_row_for_item $last_current $catalog_first_visible $catalog_last_visible component_categories[@])
                local new_screen_row=$(get_screen_row_for_item $current $catalog_first_visible $catalog_last_visible component_categories[@])
                
                tput cup $old_screen_row 2
                printf "  "
                
                tput cup $new_screen_row 2
                printf "%b%s%b " "$CATALOG_CURSOR_COLOR" "$ICON_CURSOR" "$STYLE_RESET"
            else
                render_catalog $catalog_page page_boundaries $total_items $content_height $catalog_width \
                              $view $current ids names groups requires component_categories \
                              in_cart categories category_names catalog_first_visible catalog_last_visible
            fi
        fi
        
        # Handle cart rendering
        if [[ $last_cart_page != $cart_page || $last_view != $view || $last_cart_cursor != $cart_cursor || $force_cart_update == true ]]; then
            render_cart $cart_start_col $cart_width $content_height $view $cart_cursor \
                       in_cart ids names component_categories categories category_names
            last_cart_page=$cart_page
            force_cart_update=false
        fi
        
        # Update instructions if view changed
        if [[ $last_view != $view ]]; then
            display_ui_instructions $view $term_height $term_width
        fi
        
        # Display hint message
        if [[ $hint_timer -gt 0 ]]; then
            tput cup $((content_height + 5)) 0
            tput el
            local hint_pos=$(( (term_width - ${#hint_message}) / 2 ))
            tput cup $((content_height + 5)) $hint_pos
            printf "%b%s%b" "$GLOBAL_HINT_STYLE" "$hint_message" "$STYLE_RESET"
            ((hint_timer--))
        elif [[ $hint_timer -eq 0 && -n "$hint_message" ]]; then
            tput cup $((content_height + 5)) 0
            tput el
            hint_message=""
        fi
        
        # Save state
        last_current=$current
        last_cart_cursor=$cart_cursor
        last_view=$view
        
        # Read key and handle input
        IFS= read -rsn1 key
        
        # Count cart items for navigation
        local cart_items_count=0
        for ic in "${in_cart[@]}"; do [[ $ic == true ]] && ((cart_items_count++)); done
        
        if [[ $key == "$ESC" ]]; then
            # Read more characters for escape sequences
            read -rsn1 bracket
            if [[ $bracket == '[' ]]; then
                # CSI sequence - read the rest
                read -rsn1 char1
                
                case "$char1" in
                    '3') # Possible DELETE key sequence
                        read -rsn1 char2
                        if [[ $char2 == '~' ]] && [[ $view == "cart" ]]; then
                            # Handle delete in cart
                            local cart_items_array=()
                            for idx in "${!in_cart[@]}"; do
                                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                            done
                            
                            if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                                hint_message="No items in cart to remove"
                                hint_timer=30
                            elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                                local item_idx=${cart_items_array[$cart_cursor]}
                                toggle_cart_item $item_idx "remove" ids names groups requires in_cart hint_message hint_timer
                                
                                # Rebuild cart items array after removal
                                cart_items_array=()
                                for idx in "${!in_cart[@]}"; do
                                    [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                                done
                                
                                local new_count=${#cart_items_array[@]}
                                [[ $cart_cursor -ge $new_count && $cart_cursor -gt 0 ]] && ((cart_cursor--))
                                
                                force_catalog_update=true
                                force_cart_update=true
                            fi
                        fi
                        ;;
                    'A') # Up arrow
                        local nav_result=$(handle_up_key "$view" "$current" "$cart_cursor" "$catalog_page" "$catalog_first_visible")
                        parse_nav_result "$nav_result"
                        ;;
                    'B') # Down arrow
                        local nav_result=$(handle_down_key "$view" "$current" "$cart_cursor" "$catalog_page" "$catalog_last_visible" "$total_pages" "$total_items" "$cart_items_count")
                        parse_nav_result "$nav_result"
                        ;;
                    'C') # Right arrow
                        local nav_result=$(handle_right_key "$view" "$current" "$cart_cursor" "$catalog_page" "$total_pages")
                        parse_nav_result "$nav_result"
                        ;;
                    'D') # Left arrow
                        local nav_result=$(handle_left_key "$view" "$current" "$cart_cursor" "$catalog_page")
                        parse_nav_result "$nav_result"
                        ;;
                    'P') # Alternative DELETE on some terminals
                        if [[ $view == "cart" ]]; then
                            # Handle delete in cart
                            local cart_items_array=()
                            for idx in "${!in_cart[@]}"; do
                                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                            done
                            
                            if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                                hint_message="No items in cart to remove"
                                hint_timer=30
                            elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                                local item_idx=${cart_items_array[$cart_cursor]}
                                toggle_cart_item $item_idx "remove" ids names groups requires in_cart hint_message hint_timer
                                
                                # Rebuild cart items array after removal
                                cart_items_array=()
                                for idx in "${!in_cart[@]}"; do
                                    [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                                done
                                
                                local new_count=${#cart_items_array[@]}
                                [[ $cart_cursor -ge $new_count && $cart_cursor -gt 0 ]] && ((cart_cursor--))
                                
                                force_catalog_update=true
                                force_cart_update=true
                            fi
                        fi
                        ;;
                esac
            elif [[ $bracket == 'O' ]]; then
                # SS3 sequence - read one more
                read -rsn1 char1
                case "$char1" in
                    'A') # Up arrow (alternative)
                        local nav_result=$(handle_up_key "$view" "$current" "$cart_cursor" "$catalog_page" "$catalog_first_visible")
                        parse_nav_result "$nav_result"
                        ;;
                    'B') # Down arrow (alternative)
                        local nav_result=$(handle_down_key "$view" "$current" "$cart_cursor" "$catalog_page" "$catalog_last_visible" "$total_pages" "$total_items" "$cart_items_count")
                        parse_nav_result "$nav_result"
                        ;;
                    'C') # Right arrow (alternative)
                        local nav_result=$(handle_right_key "$view" "$current" "$cart_cursor" "$catalog_page" "$total_pages")
                        parse_nav_result "$nav_result"
                        ;;
                    'D') # Left arrow (alternative)
                        local nav_result=$(handle_left_key "$view" "$current" "$cart_cursor" "$catalog_page")
                        parse_nav_result "$nav_result"
                        ;;
                esac
            fi
        elif [[ -z "$key" ]]; then
            break  # Enter key
        elif [[ "$key" == "$TAB" ]]; then
            view=$([[ $view == "catalog" ]] && echo "cart" || echo "catalog")
            [[ $view == "cart" ]] && cart_cursor=0
        elif [[ "$key" == " " && $view == "catalog" ]]; then
            if [[ $current -ge 0 ]] && [[ $current -lt ${#ids[@]} ]]; then
                if [[ "${in_cart[$current]}" == true ]]; then
                    # Remove from cart
                    in_cart[$current]=false
                    
                    # Check for dependent items
                    local removed_group="${groups[$current]}"
                    local dependents=""
                    
                    for j in "${!requires[@]}"; do
                        [[ -z "${requires[$j]}" ]] && continue
                        
                        # Check if this item depends on the removed group
                        if [[ "${requires[$j]}" == *"$removed_group"* ]] && [[ "${in_cart[$j]}" == true ]]; then
                            # Double-check this is the only item providing the requirement
                            local still_has_provider=false
                            for k in "${!groups[@]}"; do
                                if [[ $k -ne $current ]] && [[ "${groups[$k]}" == "$removed_group" ]] && [[ "${in_cart[$k]}" == true ]]; then
                                    still_has_provider=true
                                    break
                                fi
                            done
                            
                            if [[ $still_has_provider == false ]]; then
                                in_cart[$j]=false
                                [[ -n "$dependents" ]] && dependents+=", "
                                dependents+="${names[$j]}"
                            fi
                        fi
                    done
                    
                    if [[ -n "$dependents" ]]; then
                        hint_message="${ICON_WARNING}  Also removed dependent items: $dependents"
                        hint_timer=40
                    else
                        hint_message="${ICON_SUCCESS} Removed ${names[$current]} from cart"
                        hint_timer=20
                    fi
                else
                    # Add to cart
                    # Check requirements
                    if [[ -n "${requires[$current]}" ]] && [[ "${requires[$current]}" != "[]" ]]; then
                        if ! requirements_met "${requires[$current]}" "${groups[@]}" "${in_cart[@]}"; then
                            hint_message="${ICON_WARNING}  Requires: ${requires[$current]}"
                            hint_timer=30
                        else
                            # Handle mutually exclusive groups
                            for j in "${!groups[@]}"; do
                                if [[ "${groups[$j]}" == "${groups[$current]}" ]] && [[ $j -ne $current ]] && [[ "${in_cart[$j]}" == true ]]; then
                                    in_cart[$j]=false
                                    hint_message="${ICON_INFO}  Replaced ${names[$j]} with ${names[$current]}"
                                    hint_timer=30
                                fi
                            done
                            
                            in_cart[$current]=true
                            [[ -z "$hint_message" ]] && hint_message="${ICON_SUCCESS} Added ${names[$current]} to stack" && hint_timer=20
                        fi
                    else
                        # No requirements, just handle mutually exclusive groups
                        for j in "${!groups[@]}"; do
                            if [[ "${groups[$j]}" == "${groups[$current]}" ]] && [[ $j -ne $current ]] && [[ "${in_cart[$j]}" == true ]]; then
                                in_cart[$j]=false
                                hint_message="${ICON_INFO}  Replaced ${names[$j]} with ${names[$current]}"
                                hint_timer=30
                            fi
                        done
                        
                        in_cart[$current]=true
                        [[ -z "$hint_message" ]] && hint_message="${ICON_SUCCESS} Added ${names[$current]} to stack" && hint_timer=20
                    fi
                fi
                force_catalog_update=true
                force_cart_update=true
            fi 
        elif [[ "$key" =~ ^[jJ]$ ]]; then
            local nav_result=$(handle_down_key "$view" "$current" "$cart_cursor" "$catalog_page" "$catalog_last_visible" "$total_pages" "$total_items" "$cart_items_count")
            parse_nav_result "$nav_result"
        elif [[ "$key" =~ ^[kK]$ ]]; then
            local nav_result=$(handle_up_key "$view" "$current" "$cart_cursor" "$catalog_page" "$catalog_first_visible")
            parse_nav_result "$nav_result"
        elif [[ "$key" =~ ^[hH]$ && $view == "catalog" ]]; then
            local nav_result=$(handle_left_key "$view" "$current" "$cart_cursor" "$catalog_page")
            parse_nav_result "$nav_result"
        elif [[ "$key" =~ ^[lL]$ && $view == "catalog" ]]; then
            local nav_result=$(handle_right_key "$view" "$current" "$cart_cursor" "$catalog_page" "$total_pages")
            parse_nav_result "$nav_result"
        elif [[ "$key" =~ ^[dD]$ && $view == "cart" ]]; then
            # Handle 'd' key for delete in cart
            local cart_items_array=()
            for idx in "${!in_cart[@]}"; do
                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
            done
            
            if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                hint_message="No items in cart to remove"
                hint_timer=30
            elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                local item_idx=${cart_items_array[$cart_cursor]}
                toggle_cart_item $item_idx "remove" ids names groups requires in_cart hint_message hint_timer
                
                # Rebuild cart items array after removal
                cart_items_array=()
                for idx in "${!in_cart[@]}"; do
                    [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                done
                
                local new_count=${#cart_items_array[@]}
                [[ $cart_cursor -ge $new_count && $cart_cursor -gt 0 ]] && ((cart_cursor--))
                
                force_catalog_update=true
                force_cart_update=true
            fi
        elif [[ "$key" == "$BACKSPACE" && $view == "cart" ]]; then
            # Handle backspace for delete in cart
            local cart_items_array=()
            for idx in "${!in_cart[@]}"; do
                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
            done
            
            if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                hint_message="No items in cart to remove"
                hint_timer=30
            elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                local item_idx=${cart_items_array[$cart_cursor]}
                toggle_cart_item $item_idx "remove" ids names groups requires in_cart hint_message hint_timer
                
                # Rebuild cart items array after removal
                cart_items_array=()
                for idx in "${!in_cart[@]}"; do
                    [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                done
                
                local new_count=${#cart_items_array[@]}
                [[ $cart_cursor -ge $new_count && $cart_cursor -gt 0 ]] && ((cart_cursor--))
                
                force_catalog_update=true
                force_cart_update=true
            fi
        elif [[ "$key" =~ ^[qQ]$ ]]; then
            tput cnorm
            stty echo
            clear
            log "Installation cancelled."
            exit 0
        fi
        
        # Check for exit conditions (moved outside of input handling)
        if [[ "$key" == "$NL" ]] || [[ -z "$key" ]]; then
            break  # Enter key
        fi
    done
    
    tput cnorm
    stty echo
    clear
    
    # Display summary and save selections
    display_selection_summary in_cart ids names groups component_categories \
                            requires yaml_files categories category_names
    
    set -e
}

# Display UI instructions based on current view
display_ui_instructions() {
    local view=$1
    local term_height=$2
    local term_width=$3
    
    tput cup $((term_height - 1)) 0
    tput el
    
    # Build the instruction text based on view
    local instruction_text=""
    if [[ $view == "catalog" ]]; then
        instruction_text="↑↓/jk: Navigate  ←→/hl: Page  SPACE: Add to stack  TAB: Switch to stack  ENTER: Build  q: Cancel"
    else
        instruction_text="↑↓/jk: Navigate  DEL/d: Remove  TAB: Switch to catalog  ENTER: Build  q: Cancel"
    fi
    
    # Calculate center position
    local text_len=${#instruction_text}
    local start_pos=$(( (term_width - text_len) / 2 ))
    
    # Move to center position
    tput cup $((term_height - 1)) $start_pos
    
    # Print with formatting
    if [[ $view == "catalog" ]]; then
        printf "%b↑↓/jk:%b Navigate  %b←→/hl:%b Page  %bSPACE:%b Add to stack  %bTAB:%b Switch to stack  %bENTER:%b Build  %bq:%b Cancel" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE"
    else
        printf "%b↑↓/jk:%b Navigate  %bDEL/d:%b Remove  %bTAB:%b Switch to catalog  %bENTER:%b Build  %bq:%b Cancel" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE" \
            "$INSTRUCTION_KEY_STYLE" "$INSTRUCTION_TEXT_STYLE"
    fi
}

# Handle UI input - Fixed version
handle_ui_input() {
    local -n key_ref=$1
    local -n view_ref=$2
    local -n current_ref=$3
    local -n cart_cursor_ref=$4
    local -n catalog_page_ref=$5
    local -n cart_page_ref=$6
    local -n position_cursor_ref=$7
    local total_pages=$8
    local total_items=$9
    local catalog_first_visible=${10}
    local catalog_last_visible=${11}
    local -n ids_ref=$12
    local -n names_ref=$13
    local -n groups_ref=$14
    local -n requires_ref=$15
    local -n in_cart_ref=$16
    local -n hint_message_ref=$17
    local -n hint_timer_ref=$18
    local -n force_catalog_update_ref=$19
    local -n force_cart_update_ref=$20
    
    if [[ $key_ref == "$ESC" ]]; then
        # Read more characters for escape sequences
        read -rsn1 bracket
        if [[ $bracket == '[' ]]; then
            # CSI sequence - read the rest
            read -rsn1 char1
            
            case "$char1" in
                '3') # Possible DELETE key sequence
                    read -rsn1 char2
                    if [[ $char2 == '~' ]]; then
                        handle_delete_key view_ref cart_cursor_ref in_cart_ref ids_ref names_ref groups_ref requires_ref \
                                        hint_message_ref hint_timer_ref force_catalog_update_ref force_cart_update_ref
                    fi
                    ;;
                'A') # Up arrow
                    handle_up_key view_ref current_ref cart_cursor_ref catalog_page_ref \
                                 position_cursor_ref $catalog_first_visible in_cart_ref
                    ;;
                'B') # Down arrow
                    handle_down_key view_ref current_ref cart_cursor_ref catalog_page_ref \
                                   position_cursor_ref $catalog_last_visible $total_pages $total_items in_cart_ref
                    ;;
                'C') # Right arrow
                    handle_right_key view_ref catalog_page_ref position_cursor_ref $total_pages
                    ;;
                'D') # Left arrow
                    handle_left_key view_ref catalog_page_ref position_cursor_ref
                    ;;
                'P') # Alternative DELETE on some terminals
                    handle_delete_key view_ref cart_cursor_ref in_cart_ref ids_ref names_ref groups_ref requires_ref \
                                    hint_message_ref hint_timer_ref force_catalog_update_ref force_cart_update_ref
                    ;;
            esac
        elif [[ $bracket == 'O' ]]; then
            # SS3 sequence - read one more
            read -rsn1 char1
            case "$char1" in
                'A') # Up arrow (alternative)
                    handle_up_key view_ref current_ref cart_cursor_ref catalog_page_ref \
                                 position_cursor_ref $catalog_first_visible in_cart_ref
                    ;;
                'B') # Down arrow (alternative)
                    handle_down_key view_ref current_ref cart_cursor_ref catalog_page_ref \
                                   position_cursor_ref $catalog_last_visible $total_pages $total_items in_cart_ref
                    ;;
                'C') # Right arrow (alternative)
                    handle_right_key view_ref catalog_page_ref position_cursor_ref $total_pages
                    ;;
                'D') # Left arrow (alternative)
                    handle_left_key view_ref catalog_page_ref position_cursor_ref
                    ;;
            esac
        fi
    elif [[ "$key_ref" == "$TAB" ]]; then
        view_ref=$([[ $view_ref == "catalog" ]] && echo "cart" || echo "catalog")
        [[ $view_ref == "cart" ]] && cart_cursor_ref=0
    elif [[ "$key_ref" == " " ]]; then
        if [[ $view_ref == "catalog" ]]; then
            if [[ $current_ref -ge 0 ]] && [[ $current_ref -lt ${#ids_ref[@]} ]]; then
                if [[ "${in_cart_ref[$current_ref]}" == true ]]; then
                    toggle_cart_item $current_ref "remove" ids_ref names_ref groups_ref requires_ref in_cart_ref hint_message_ref hint_timer_ref
                else
                    toggle_cart_item $current_ref "add" ids_ref names_ref groups_ref requires_ref in_cart_ref hint_message_ref hint_timer_ref
                fi
                force_catalog_update_ref=true
                force_cart_update_ref=true
            fi
        fi
    elif [[ "$key_ref" =~ ^[jJ]$ ]]; then
        handle_down_key view_ref current_ref cart_cursor_ref catalog_page_ref \
                       position_cursor_ref $catalog_last_visible $total_pages $total_items in_cart_ref
    elif [[ "$key_ref" =~ ^[kK]$ ]]; then
        handle_up_key view_ref current_ref cart_cursor_ref catalog_page_ref \
                     position_cursor_ref $catalog_first_visible in_cart_ref
    elif [[ "$key_ref" =~ ^[hH]$ && $view_ref == "catalog" ]]; then
        handle_left_key view_ref catalog_page_ref position_cursor_ref
    elif [[ "$key_ref" =~ ^[lL]$ && $view_ref == "catalog" ]]; then
        handle_right_key view_ref catalog_page_ref position_cursor_ref $total_pages
    elif [[ "$key_ref" =~ ^[dD]$ && $view_ref == "cart" ]]; then
        handle_delete_key view_ref cart_cursor_ref in_cart_ref ids_ref names_ref groups_ref requires_ref \
                        hint_message_ref hint_timer_ref force_catalog_update_ref force_cart_update_ref
    elif [[ "$key_ref" == "$BACKSPACE" && $view_ref == "cart" ]]; then
        handle_delete_key view_ref cart_cursor_ref in_cart_ref ids_ref names_ref groups_ref requires_ref \
                        hint_message_ref hint_timer_ref force_catalog_update_ref force_cart_update_ref
    fi
}

# Handle navigation keys - Fixed for Bash 3.2+
handle_up_key() {
    local view="$1"
    local current="$2"
    local cart_cursor="$3"
    local catalog_page="$4"
    local catalog_first_visible="$5"
    local result=""
    
    if [[ $view == "catalog" ]]; then
        if [[ $current -eq $catalog_first_visible ]] && [[ $catalog_page -gt 0 ]]; then
            ((catalog_page--))
            echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor=last"
        elif ((current > 0)); then
            ((current--))
            echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
        else
            echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
        fi
    else
        if ((cart_cursor > 0)); then
            ((cart_cursor--))
        fi
        echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
    fi
}

handle_down_key() {
    local view="$1"
    local current="$2"
    local cart_cursor="$3"
    local catalog_page="$4"
    local catalog_last_visible="$5"
    local total_pages="$6"
    local total_items="$7"
    local cart_items_count="$8"
    
    if [[ $view == "catalog" ]]; then
        if [[ $current -eq $catalog_last_visible ]] && [[ $catalog_page -lt $((total_pages - 1)) ]]; then
            ((catalog_page++))
            echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor=first"
        elif ((current < total_items - 1)); then
            ((current++))
            echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
        else
            echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
        fi
    else
        if ((cart_cursor < cart_items_count - 1)); then
            ((cart_cursor++))
        fi
        echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
    fi
}

handle_left_key() {
    local view="$1"
    local current="$2"
    local cart_cursor="$3"
    local catalog_page="$4"
    
    if [[ $view == "catalog" && $catalog_page -gt 0 ]]; then
        ((catalog_page--))
        echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor=first"
    else
        echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
    fi
}

handle_right_key() {
    local view="$1"
    local current="$2"
    local cart_cursor="$3"
    local catalog_page="$4"
    local total_pages="$5"
    
    if [[ $view == "catalog" && $catalog_page -lt $((total_pages - 1)) ]]; then
        ((catalog_page++))
        echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor=first"
    else
        echo "view=$view:current=$current:cart_cursor=$cart_cursor:catalog_page=$catalog_page:position_cursor="
    fi
}

# Parse navigation result
parse_nav_result() {
    local result="$1"
    local -a parts
    IFS=':' read -ra parts <<< "$result"
    
    for part in "${parts[@]}"; do
        if [[ $part =~ ^view=(.*)$ ]]; then
            view="${BASH_REMATCH[1]}"
        elif [[ $part =~ ^current=(.*)$ ]]; then
            current="${BASH_REMATCH[1]}"
        elif [[ $part =~ ^cart_cursor=(.*)$ ]]; then
            cart_cursor="${BASH_REMATCH[1]}"
        elif [[ $part =~ ^catalog_page=(.*)$ ]]; then
            catalog_page="${BASH_REMATCH[1]}"
        elif [[ $part =~ ^position_cursor=(.*)$ ]]; then
            position_cursor_after_render="${BASH_REMATCH[1]}"
        fi
    done
}

handle_delete_key() {
    local view_var=$1
    local cart_cursor_var=$2
    local in_cart=("${!3}")
    local ids=("${!4}")
    local names=("${!5}")
    local groups=("${!6}")
    local requires=("${!7}")
    local hint_message_var=$8
    local hint_timer_var=$9
    local force_catalog_update_var=${10}
    local force_cart_update_var=${11}
    
    eval "local view=\$$view_var"
    eval "local cart_cursor=\$$cart_cursor_var"
    
    if [[ $view == "cart" ]]; then
        local cart_items_array=()
        for idx in "${!in_cart[@]}"; do
            [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
        done
        
        if [[ ${#cart_items_array[@]} -eq 0 ]]; then
            eval "$hint_message_var=\"No items in cart to remove\""
            eval "$hint_timer_var=30"
        elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
            local item_idx=${cart_items_array[$cart_cursor]}
            
            toggle_cart_item $item_idx "remove" ids[@] names[@] groups[@] requires[@] in_cart[@] "$hint_message_var" "$hint_timer_var"
            
            # Rebuild cart items array after removal
            cart_items_array=()
            for idx in "${!in_cart[@]}"; do
                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
            done
            
            local new_count=${#cart_items_array[@]}
            [[ $cart_cursor -ge $new_count && $cart_cursor -gt 0 ]] && eval "((${cart_cursor_var}--))"
            
            eval "$force_catalog_update_var=true"
            eval "$force_cart_update_var=true"
        fi
    fi
}

# Display selection summary with deployment status
display_selection_summary() {
    local in_cart=("${!1}")
    local ids=("${!2}")
    local names=("${!3}")
    local groups=("${!4}")
    local component_categories=("${!5}")
    local requires=("${!6}")
    local yaml_files=("${!7}")
    local categories=("${!8}")
    local category_names=("${!9}")
    
    # Build final selections - Summary Screen
    local term_width=$(tput cols)
    local term_height=$(tput lines)

    # Clear screen
    clear

    # Draw gradient title
    draw_gradient_title "AI DevKit Pod Configurator" 1   

    # Add spacing
    echo ""

    # Calculate box dimensions - now with two panes
    local manifest_width=$((term_width / 2 - 2))
    local status_start_col=$((manifest_width + 3))
    local status_width=$((term_width - status_start_col))
    local box_height=$((term_height - 8)) # Leave room for title, spacing, and prompt

    # Draw the manifest box
    draw_box 2 3 $manifest_width $box_height "Deployment Manifest" "" "$SUMMARY_BORDER_COLOR" "$SUMMARY_TITLE_STYLE"
    
    # Draw the status box
    draw_box $status_start_col 3 $status_width $box_height "Deployment Status" "" "$STATUS_BORDER_COLOR" "$STATUS_TITLE_STYLE"
   
    # Start content inside the box
    local content_row=5  # Start 2 rows inside the box for spacing

    # Show base components first - just like Build Stack
    tput cup $content_row 6
    style_line "$SUMMARY_CATEGORY_STYLE" "Base Development Tools"
    ((content_row++))

    # Base components with checkmarks
    local base_items=(
        "Filebrowser (port 8090)"
        "Git"
        "GitHub CLI (gh)"
        "Microsoft TUI Test"
        "Node.js 20.18.0"
        "SSH Server (port 2222)"
    )

    for item in "${base_items[@]}"; do
        if [[ $content_row -lt $((box_height + 3)) ]]; then
            tput cup $content_row 8
            echo -e "${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} ${item}"
            ((content_row++))
        fi
    done

    # Count selections
    local selection_count=0
    for i in "${!in_cart[@]}"; do
        [[ "${in_cart[$i]}" == true ]] && ((selection_count++))
    done

    if [[ $selection_count -gt 0 ]]; then
        # Store selections
        SELECTED_YAML_FILES=()
        SELECTED_IDS=()
        SELECTED_NAMES=()
        SELECTED_GROUPS=()
        SELECTED_CATEGORIES=()
        SELECTED_REQUIRES=()
        
        # Display selected items grouped by category
        for cat_idx in "${!categories[@]}"; do
            local category="${categories[$cat_idx]}"
            local category_display="${category_names[$cat_idx]}"
            local category_has_items=false
            
            for i in "${!ids[@]}"; do
                if [[ "${in_cart[$i]}" == true ]] && [[ "${component_categories[$i]}" == "$category" ]]; then
                    if [[ $category_has_items == false ]] && [[ $content_row -lt $((box_height + 3)) ]]; then
                        ((content_row++))  # Single line spacing between categories
                        tput cup $content_row 6
                        style_line "$SUMMARY_CATEGORY_STYLE" "$category_display"
                        ((content_row++))
                        category_has_items=true
                    fi
                    
                    if [[ $content_row -lt $((box_height + 3)) ]]; then
                        tput cup $content_row 8
                        echo -e "${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} ${names[$i]}"
                        ((content_row++))
                    fi
                    
                    # Store selection details
                    SELECTED_YAML_FILES+=("${yaml_files[$i]}")
                    SELECTED_IDS+=("${ids[$i]}")
                    SELECTED_NAMES+=("${names[$i]}")
                    SELECTED_GROUPS+=("${groups[$i]}")
                    SELECTED_CATEGORIES+=("${component_categories[$i]}")
                    SELECTED_REQUIRES+=("${requires[$i]}")
                fi
            done
        done
    fi

    # Initial status message
    tput cup 5 $((status_start_col + 2))
    printf "%b%s%b %b%s%b" "$STATUS_PENDING_STYLE" "$ICON_PENDING" "$STYLE_RESET" "$STATUS_STEP_STYLE" "Ready to build?" "$STYLE_RESET"

    # Position prompt below the boxes
    local prompt_row=$((box_height + 5))
    tput cup $prompt_row 4
    log "Ready to build with this configuration?"
    tput cup $((prompt_row + 1)) 4
    printf "Press %bENTER%b to continue or %b'q'%b to quit: " \
        "$LOG_SUCCESS_STYLE" "$STYLE_RESET" \
        "$LOG_ERROR_STYLE" "$STYLE_RESET"
    read -r CONFIRM 

    if [[ "$CONFIRM" =~ ^[qQ]$ ]]; then
        tput cnorm
        stty echo
        clear
        log "Build cancelled."
        exit 0
    fi
}

# Global variables for selected items
declare -a SELECTED_YAML_FILES
declare -a SELECTED_IDS
declare -a SELECTED_NAMES
declare -a SELECTED_GROUPS
declare -a SELECTED_CATEGORIES
declare -a SELECTED_REQUIRES

# Global arrays for categories
declare -a categories
declare -a category_names

# Function to extract pre_build_script from YAML file
extract_pre_build_script() {
    local yaml_file=$1
    local script_name=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^pre_build_script:[[:space:]]*(.+)$ ]]; then
            script_name="${BASH_REMATCH[1]}"
            # Remove quotes if present
            script_name="${script_name#\"}"
            script_name="${script_name%\"}"
            script_name="${script_name#\'}"
            script_name="${script_name%\'}"
            break
        fi
    done < "$yaml_file"
    
    echo "$script_name"
}

# Function to execute pre-build scripts
execute_pre_build_scripts() {
    log "Executing pre-build scripts..."
    
    local selected_ids="${SELECTED_IDS[*]}"
    local selected_names="${SELECTED_NAMES[*]}"
    local selected_yaml_files="${SELECTED_YAML_FILES[*]}"
    
    for i in "${!SELECTED_YAML_FILES[@]}"; do
        local yaml_file="${SELECTED_YAML_FILES[$i]}"
        local component_name="${SELECTED_NAMES[$i]}"
        
        # Extract pre_build_script
        local script_name=$(extract_pre_build_script "$yaml_file")
        
        if [[ -n "$script_name" ]]; then
            local script_dir=$(dirname "$yaml_file")
            local script_path="$script_dir/$script_name"
            
            if [[ -f "$script_path" ]]; then
                log "Running pre-build script for $component_name..."
                
                # Make script executable
                chmod +x "$script_path"
                
                # Execute with standard arguments
                if "$script_path" "$TEMP_DIR" "$selected_ids" "$selected_names" "$selected_yaml_files" "$script_dir"; then
                    success "Pre-build script completed for $component_name"
                else
                    error "Pre-build script failed for $component_name"
                fi
            else
                warning "Pre-build script $script_name not found for $component_name"
            fi
        fi
    done
}

# Function to extract inject_files from YAML
extract_inject_files_from_yaml() {
    local yaml_file=$1
    local in_inject_files=false
    local current_item=false
    local source="" destination="" permissions=""
    local inject_commands=""
    
    while IFS= read -r line; do
        # Check if entering inject_files section
        if [[ "$line" =~ ^[[:space:]]*inject_files:[[:space:]]*$ ]]; then
            in_inject_files=true
            continue
        fi
        
        # Check if exiting inject_files section
        if [[ $in_inject_files == true ]] && [[ "$line" =~ ^[a-zA-Z_]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_inject_files=false
            break
        fi
        
        if [[ $in_inject_files == true ]]; then
            # New item starts with - source:
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+source:[[:space:]]*(.+)$ ]]; then
                # Process previous item if exists
                if [[ -n "$source" ]] && [[ -n "$destination" ]]; then
                    inject_commands+="COPY $source $destination"$NL
                    if [[ -n "$permissions" ]]; then
                        inject_commands+="RUN chmod $permissions $destination"$NL
                    fi
                fi
                
                # Start new item
                source="${BASH_REMATCH[1]}"
                destination=""
                permissions=""
                current_item=true
            elif [[ $current_item == true ]]; then
                if [[ "$line" =~ ^[[:space:]]+destination:[[:space:]]*(.+)$ ]]; then
                    destination="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^[[:space:]]+permissions:[[:space:]]*(.+)$ ]]; then
                    permissions="${BASH_REMATCH[1]}"
                fi
            fi
        fi
    done < "$yaml_file"
    
    # Process last item
    if [[ -n "$source" ]] && [[ -n "$destination" ]]; then
        inject_commands+="COPY $source $destination"$NL
        if [[ -n "$permissions" ]]; then
            inject_commands+="RUN chmod $permissions $destination"$NL
        fi
    fi
    
    echo -n "$inject_commands"
}

# Function to extract entrypoint_setup from YAML file
extract_entrypoint_setup() {
    local yaml_file=$1
    local in_entrypoint_setup=false
    local entrypoint_content=""
    
    while IFS= read -r line; do
        # Check if we're entering entrypoint_setup section
        if [[ "$line" =~ ^entrypoint_setup:[[:space:]]*\|[[:space:]]*$ ]]; then
            in_entrypoint_setup=true
            continue
        fi
        
        # Check if we're exiting entrypoint_setup section (new top-level key)
        if [[ $in_entrypoint_setup == true ]] && [[ "$line" =~ ^[a-zA-Z_]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_entrypoint_setup=false
            break
        fi
        
        # Collect entrypoint_setup lines
        if [[ $in_entrypoint_setup == true ]]; then
            # Remove the first 2 spaces of YAML indentation
            if [[ "$line" =~ ^"  " ]]; then
                entrypoint_content+="${line:2}"$NL
            elif [[ -z "$line" ]]; then
                # Preserve empty lines
                entrypoint_content+=$NL
            fi
        fi
    done < "$yaml_file"
    
    # Trim trailing newlines but keep the content intact
    # Don't use complex sed operations that might corrupt the content
    while [[ "$entrypoint_content" =~ ${NL}$ ]]; do
        entrypoint_content="${entrypoint_content%$NL}"
    done
    
    echo "$entrypoint_content"
}

# Function to extract installation commands from YAML files
extract_installation_from_yaml() {
    local yaml_file=$1
    local in_dockerfile=false
    local in_nexus=false
    local dockerfile_content=""
    local nexus_content=""
    
    while IFS= read -r line; do
        # Check for dockerfile section
        if [[ "$line" =~ ^[[:space:]]*dockerfile:[[:space:]]*\|[[:space:]]*$ ]]; then
            in_dockerfile=true
            in_nexus=false
            continue
        fi
        
        # Check for nexus_config section
        if [[ "$line" =~ ^[[:space:]]*nexus_config:[[:space:]]*\|[[:space:]]*$ ]]; then
            in_nexus=true
            in_dockerfile=false
            continue
        fi
        
        # Check if we're exiting a section
        if [[ "$line" =~ ^[[:space:]]*[a-zA-Z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4,} ]]; then
            in_dockerfile=false
            in_nexus=false
        fi
        
        # Collect content
        if [[ $in_dockerfile == true ]]; then
            # For dockerfile content, we need to preserve the exact formatting
            # Only remove the first 4 spaces that are YAML indentation
            if [[ "$line" =~ ^"    " ]]; then
                dockerfile_content+="${line:4}"$NL
            else
                # Handle empty lines or lines with different indentation
                dockerfile_content+="$line"$NL
            fi
        elif [[ $in_nexus == true ]]; then
            # For nexus content, preserve it as-is after removing YAML indent
            if [[ "$line" =~ ^"    " ]]; then
                nexus_content+="${line:4}"$NL
            fi
        fi
    done < "$yaml_file"
    
    # Combine dockerfile and nexus content if applicable
    local full_content="$dockerfile_content"
    if [[ -n "$nexus_content" ]]; then
        # The nexus_config should already be properly formatted in the YAML
        # Just wrap it in RUN - but be careful with the newline
        if [[ -n "$full_content" ]]; then
            full_content+=$NL
        fi
        full_content+="# Nexus configuration"$NL
        full_content+="RUN ${nexus_content}"
    fi
    
    printf "%s" "$full_content"
}

# Function to sort components by dependencies (topological sort)
sort_components_by_dependencies() {
    local -a sorted_indices=()
    local -a visited=()
    local -a in_progress=()
    
    # Initialize arrays
    for i in "${!SELECTED_IDS[@]}"; do
        visited[$i]=false
        in_progress[$i]=false
    done
    
    # Helper function for DFS
    visit_component() {
        local idx=$1
        
        if [[ "${in_progress[$idx]}" == true ]]; then
            error "Circular dependency detected involving ${SELECTED_NAMES[$idx]}"
        fi
        
        if [[ "${visited[$idx]}" == true ]]; then
            return
        fi
        
        in_progress[$idx]=true
        
        # Get the requires field for this component
        local requires="${SELECTED_REQUIRES[$idx]}"
        
        # Visit dependencies first
        if [[ -n "$requires" ]] && [[ "$requires" != "[]" ]] && [[ "$requires" != "" ]]; then
            # Parse requires field (could be space-separated)
            for req in $requires; do
                # Find components that provide this requirement
                for dep_idx in "${!SELECTED_IDS[@]}"; do
                    local dep_group="${SELECTED_GROUPS[$dep_idx]}"
                    
                    if [[ "$dep_group" == "$req" ]]; then
                        visit_component $dep_idx
                    fi
                done
            done
        fi
        
        in_progress[$idx]=false
        visited[$idx]=true
        sorted_indices+=($idx)
    }
    
    # Visit all components
    for i in "${!SELECTED_IDS[@]}"; do
        if [[ "${visited[$i]}" == false ]]; then
            visit_component $i
        fi
    done
    
    # Return sorted indices
    echo "${sorted_indices[@]}"
}

# Function to create custom Dockerfile
create_custom_dockerfile() {
    mkdir -p "$TEMP_DIR"
    
    # First, generate the base entrypoint.sh in TEMP_DIR
    log "Generating custom entrypoint.sh..."
    
    # Check if entrypoint.base.sh exists
    if [[ ! -f "entrypoint.base.sh" ]]; then
        error "entrypoint.base.sh not found in current directory: $(pwd)"
    fi
    
    log "Copying entrypoint.base.sh to $TEMP_DIR/entrypoint.sh"
    cp -v entrypoint.base.sh "$TEMP_DIR/entrypoint.sh"
    
    if [[ ! -f "$TEMP_DIR/entrypoint.sh" ]]; then
        error "Failed to create entrypoint.sh in $TEMP_DIR"
    fi
    
    chmod +x "$TEMP_DIR/entrypoint.sh"
    success "Successfully created entrypoint.sh in $TEMP_DIR"
    
    # Copy Dockerfile.base
    log "Copying Dockerfile.base to $TEMP_DIR/Dockerfile"
    cp Dockerfile.base "$TEMP_DIR/Dockerfile"
    
    # Execute pre-build scripts
    execute_pre_build_scripts
    
    # Create placeholder files if they don't exist (for when no components are selected)
    touch "$TEMP_DIR/user-CLAUDE.md" 2>/dev/null || true
    touch "$TEMP_DIR/component-imports.txt" 2>/dev/null || true
    
    # Sort components by dependencies
    log "Sorting components by dependencies..."
    local sorted_indices=($(sort_components_by_dependencies))
    
    # Process selected components in dependency order
    local installation_content=""
    local inject_files_content=""
    local entrypoint_setup_content=""
    
    for idx in "${sorted_indices[@]}"; do
        local yaml_file="${SELECTED_YAML_FILES[$idx]}"
        local component_name="${SELECTED_NAMES[$idx]}"
        
        log "Processing: $component_name"
        
        # Extract installation commands
        local install_cmds=$(extract_installation_from_yaml "$yaml_file")
        if [[ -n "$install_cmds" ]]; then
            if [[ -n "$installation_content" ]]; then
                installation_content+=$NL
            fi
            installation_content+="# From $yaml_file"$NL
            installation_content+="$install_cmds"
        fi
        
        # Extract inject_files directives
        local inject_cmds=$(extract_inject_files_from_yaml "$yaml_file")
        if [[ -n "$inject_cmds" ]]; then
            if [[ -n "$inject_files_content" ]]; then
                inject_files_content+=$NL
            fi
            inject_files_content+="# Files injected by $component_name"$NL
            inject_files_content+="$inject_cmds"
        fi
        
        # Extract entrypoint setup
        local entrypoint_cmds=$(extract_entrypoint_setup "$yaml_file")
        if [[ -n "$entrypoint_cmds" ]]; then
            if [[ -n "$entrypoint_setup_content" ]]; then
                entrypoint_setup_content+=$NL
            fi
            entrypoint_setup_content+="# Setup for $component_name"$NL
            entrypoint_setup_content+="$entrypoint_cmds"
        fi
    done
    
    # Insert installations
    if [[ -n "$installation_content" ]]; then
        # Remove any trailing newlines to avoid parse errors
        installation_content=$(echo -n "$installation_content")
        echo "$installation_content" > "$TEMP_DIR/installations.txt"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/r $TEMP_DIR/installations.txt" "$TEMP_DIR/Dockerfile"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak" "$TEMP_DIR/installations.txt"
    else
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak"
    fi
    
    # Insert file injections before volume declarations
    if [[ -n "$inject_files_content" ]]; then
        # Remove any trailing newlines
        inject_files_content=$(echo -n "$inject_files_content")
        echo "$inject_files_content" > "$TEMP_DIR/inject_files.txt"
        # Insert before the VOLUME declaration - add a blank line first
        sed -i.bak '/^# Set up volume mount points/i\
' "$TEMP_DIR/Dockerfile"
        sed -i.bak "/^# Set up volume mount points/r $TEMP_DIR/inject_files.txt" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak" "$TEMP_DIR/inject_files.txt"
    fi
    
    # Now modify the generated entrypoint.sh with component setup
    if [[ -n "$entrypoint_setup_content" ]]; then
        # Create temporary file with the setup content
        echo "$entrypoint_setup_content" > "$TEMP_DIR/entrypoint_setup.txt"
        
        # Insert the setup content at the placeholder
        sed -i.bak "/# COMPONENT_SETUP_PLACEHOLDER/r $TEMP_DIR/entrypoint_setup.txt" "$TEMP_DIR/entrypoint.sh"
        sed -i.bak "/# COMPONENT_SETUP_PLACEHOLDER/d" "$TEMP_DIR/entrypoint.sh"
        
        rm -f "$TEMP_DIR/entrypoint.sh.bak" "$TEMP_DIR/entrypoint_setup.txt"
    else
        # Remove the placeholder if no setup content
        sed -i.bak "/# COMPONENT_SETUP_PLACEHOLDER/d" "$TEMP_DIR/entrypoint.sh"
        rm -f "$TEMP_DIR/entrypoint.sh.bak"
    fi
    
    success "Generated custom entrypoint.sh with component setup"
    
    # Copy settings.local.json.template only if it exists (from pre-build)
    if [[ -f "$TEMP_DIR/settings.local.json.template" ]]; then
        log "settings.local.json.template found from pre-build, will be included"
    fi
}

# Check for host git configuration
check_host_git_config() {
    local config_dir="$HOME/.ai-devkit-k8s"
    
    if [[ -d "$config_dir" ]] && [[ -f "$config_dir/git-config/.gitconfig" ]]; then
        return 0
    fi
    return 1
}

# Create git configuration secret
create_git_config_secret() {
    local config_dir="$HOME/.ai-devkit-k8s"
    
    # Delete existing secret if it exists
    kubectl delete secret git-config -n ${NAMESPACE} --ignore-not-found=true >/dev/null 2>&1
    
    # Create secret from files
    local secret_args="--from-file=gitconfig=$config_dir/git-config/.gitconfig"
    
    # Add optional files if they exist
    [[ -f "$config_dir/git-config/.git-credentials" ]] && \
        secret_args="$secret_args --from-file=git-credentials=$config_dir/git-config/.git-credentials"
    
    [[ -f "$config_dir/github/hosts.yml" ]] && \
        secret_args="$secret_args --from-file=gh-hosts=$config_dir/github/hosts.yml"
    
    # Create the secret
    kubectl create secret generic git-config -n ${NAMESPACE} $secret_args >/dev/null 2>&1
}

# ============================================================================
# MAIN EXECUTION HELPER FUNCTIONS
# ============================================================================

# Function to validate environment
validate_environment() {
    check_deps
    
    [[ ! -d "$COMPONENTS_DIR" ]] && error "Components directory '$COMPONENTS_DIR' not found"
    
    # Check if MOTD file exists
    if [[ ! -f "motd-ai-devkit.sh" ]]; then
        error "motd-ai-devkit.sh not found in current directory. Please create this file first."
    fi
    
    # Check Colima status
    colima status &> /dev/null || error "Colima is not running. Please start Colima with: colima start --kubernetes"
    kubectl get nodes &> /dev/null || error "Kubernetes is not accessible. Please make sure Colima started with --kubernetes flag"
    
    success "Colima with Kubernetes is running and accessible"
}

# Function to initialize component system
initialize_components() {
    # Load categories for use in generate_claude_md
    local component_data=$(load_components)
    local categories_line=$(echo "$component_data" | sed -n '1p')
    
    # Convert to global arrays
    IFS=' ' read -ra categories <<< "$categories_line"
    
    # Read category names line by line to preserve spaces
    category_names=()
    local reading_names=false
    local line_num=0
    while IFS= read -r line; do
        ((line_num++))
        if [[ $line_num -eq 3 ]]; then
            reading_names=true
            continue
        fi
        if [[ $reading_names == true && "$line" == "---SEPARATOR---" ]]; then
            break
        fi
        if [[ $reading_names == true ]]; then
            category_names+=("$line")
        fi
    done <<< "$component_data"
}

# Function to setup configuration options
setup_configuration() {
    # Check for host git configuration
    USE_HOST_GIT_CONFIG=false
    if check_host_git_config; then
        read -p "Use host git configuration? [Y/n]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            USE_HOST_GIT_CONFIG=true
        fi
    fi
    
    # Check Nexus
    NEXUS_AVAILABLE=false
    if check_nexus; then
        NEXUS_AVAILABLE=true
        export DOCKER_BUILDKIT=0
        export NEXUS_BUILD_ARGS="--build-arg PIP_INDEX_URL=http://host.lima.internal:8081/repository/pypi-proxy/simple --build-arg PIP_TRUSTED_HOST=host.lima.internal --build-arg NPM_REGISTRY=http://host.lima.internal:8081/repository/npm-proxy/ --build-arg GOPROXY=http://host.lima.internal:8081/repository/go-proxy/ --build-arg USE_NEXUS_APT=true --build-arg NEXUS_APT_URL=http://host.lima.internal:8081"
    fi
}

# Function to cleanup previous build
cleanup_previous_build() {
    # Clean up only AFTER user confirms they want to build
    if [[ -d "$TEMP_DIR" ]]; then
        # Suppress output since we're in TUI mode
        rm -rf "$TEMP_DIR"/* 2>/dev/null
    fi
    
    # Delete the deployment to ensure fresh container
    kubectl delete deployment ai-devkit -n ${NAMESPACE} --ignore-not-found=true >> "$LOG_FILE" 2>&1
    docker rmi ${IMAGE_NAME}:${IMAGE_TAG} >> "$LOG_FILE" 2>&1 || true
}

# Function to build Docker image
build_docker_image() {
    # Create custom Dockerfile silently
    echo -e "\nDockerfile generation output:" >> "$LOG_FILE"
    echo "=================================================================================" >> "$LOG_FILE"
    create_custom_dockerfile >> "$LOG_FILE" 2>&1
    
    # Always build from TEMP_DIR since we now generate entrypoint.sh
    cp setup-git.sh "$TEMP_DIR/" 2>/dev/null
    cp motd-ai-devkit.sh "$TEMP_DIR/" 2>/dev/null
    cp nodejs-base.md "$TEMP_DIR/" 2>/dev/null
    cp -r configs "$TEMP_DIR/" 2>/dev/null
    cp -r templates "$TEMP_DIR/" 2>/dev/null

    cd "$TEMP_DIR"
    echo "Docker build output:" >> "../$LOG_FILE"
    echo "=================================================================================" >> "../$LOG_FILE"
    if [[ -n "$NEXUS_BUILD_ARGS" ]]; then
        docker build $NEXUS_BUILD_ARGS -t ${IMAGE_NAME}:${IMAGE_TAG} . >> "../$LOG_FILE" 2>&1 || \
            (cd .. && error "Docker build failed - check $LOG_FILE for details")
    else
        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} . >> "../$LOG_FILE" 2>&1 || \
            (cd .. && error "Docker build failed - check $LOG_FILE for details")
    fi
    cd ..
}

# Function to deploy to Kubernetes
deploy_to_kubernetes() {
    echo -e "\nKubernetes deployment output:" >> "$LOG_FILE"
    echo "=================================================================================" >> "$LOG_FILE"
    docker save ${IMAGE_NAME}:${IMAGE_TAG} | colima ssh -- sudo ctr -n k8s.io images import - >> "$LOG_FILE" 2>&1
    
    kubectl apply -f kubernetes/namespace.yaml >> "$LOG_FILE" 2>&1
    kubectl apply -f kubernetes/pvc.yaml >> "$LOG_FILE" 2>&1
    
    # Create git config secret if using host configuration
    if [[ "$USE_HOST_GIT_CONFIG" = true ]]; then
        create_git_config_secret
    fi
    
    # Create SSH host keys secret
    create_ssh_host_keys_secret
    
    # Apply Nexus configuration if available
    if [[ "$NEXUS_AVAILABLE" = true ]]; then
        kubectl apply -f kubernetes/nexus-config.yaml >> "$LOG_FILE" 2>&1
    fi
    
    # Apply deployment
    kubectl apply -f kubernetes/deployment.yaml >> "$LOG_FILE" 2>&1
    
    # Wait for deployment
    kubectl wait --for=condition=available --timeout=120s deployment/ai-devkit -n ${NAMESPACE} >> "$LOG_FILE" 2>&1
    
    POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=ai-devkit -o jsonpath="{.items[0].metadata.name}")
}

# Function to setup port forwarding
setup_port_forwarding() {
    pkill -f 'kubectl.*port-forward.*ai-devkit' 2>/dev/null || true
    sleep 1
    kubectl port-forward -n ${NAMESPACE} service/ai-devkit 2222:22 8090:8090 >> "$LOG_FILE" 2>&1 &
    PORT_FORWARD_PID=$!
    sleep 2
    
    # Check if port forwarding is running
    if ! ps -p $PORT_FORWARD_PID > /dev/null 2>&1; then
        # Update status in TUI context
        return 1
    fi
    return 0
}

# Refactored main function with deployment status updates
main() {
    # Initialize log file
    echo "Build started at $(date)" > "$LOG_FILE"
    echo "=================================================================================" >> "$LOG_FILE"
    
    # Initial startup message before TUI
    log "=== Starting AI DevKit Pod Configurator ==="
    
    # Validate environment
    validate_environment
    
    # Generate SSH host keys
    generate_ssh_host_keys
    
    # Initialize component system
    initialize_components
    
    # Setup configuration options
    setup_configuration
    
    # Component selection
    [[ ! "$1" =~ --no-select && ! "$2" =~ --no-select ]] && run_component_selection_ui
    
    # If we reach here, user has confirmed to build
    # Store terminal dimensions for deployment status
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local manifest_width=$((term_width / 2 - 2))
    local status_start_col=$((manifest_width + 3))
    local status_width=$((term_width - status_start_col))
    local box_height=$((term_height - 8))
    
    # Define deployment steps
    local deployment_steps=(
        "Clean previous build"
        "Build Docker image"
        "Deploy to Kubernetes"
        "Setup port forwarding"
    )
    
    local step_statuses=("pending" "pending" "pending" "pending")
    local step_messages=("" "" "" "")
    
    # Hide cursor during deployment
    tput civis
    
    # Initial render of all steps
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    # Step 1: Clean up previous build
    update_deployment_step 0 "running" "" step_statuses step_messages
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    cleanup_previous_build
    
    update_deployment_step 0 "success" "" step_statuses step_messages
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    # Step 2: Build Docker image
    update_deployment_step 1 "running" "This may take several minutes..." step_statuses step_messages
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    if build_docker_image; then
        update_deployment_step 1 "success" "" step_statuses step_messages
    else
        update_deployment_step 1 "failed" "Check $LOG_FILE for details" step_statuses step_messages
        render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
        
        tput cup $((box_height + 5)) 4
        printf "Press %bENTER%b to exit: " "$LOG_ERROR_STYLE" "$STYLE_RESET"
        read -r
        tput cnorm
        stty echo
        clear
        error "Build failed - check $LOG_FILE for details"
    fi
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    # Step 3: Deploy to Kubernetes
    update_deployment_step 2 "running" "" step_statuses step_messages
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    deploy_to_kubernetes
    
    update_deployment_step 2 "success" "Pod: $POD_NAME" step_statuses step_messages
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    # Step 4: Setup port forwarding
    update_deployment_step 3 "running" "" step_statuses step_messages
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    
    if setup_port_forwarding; then
        update_deployment_step 3 "success" "PID: $PORT_FORWARD_PID" step_statuses step_messages
    else
        update_deployment_step 3 "failed" "Check $LOG_FILE" step_statuses step_messages
    fi
    
    # Final render with all statuses
    render_deployment_steps $status_start_col $status_width deployment_steps[@] step_statuses[@] step_messages[@]
    local final_row=$DEPLOYMENT_STATUS_FINAL_ROW
    
    # Check if Claude Code was selected
    local claude_selected=false
    for id in "${SELECTED_IDS[@]}"; do
        if [[ "$id" == "CLAUDE_CODE" ]]; then
            claude_selected=true
            break
        fi
    done
    
    # Show connection details if all succeeded
    local all_success=true
    for status in "${step_statuses[@]}"; do
        if [[ "$status" == "failed" ]]; then
            all_success=false
            break
        fi
    done
    
    if [[ $all_success == true ]]; then
        show_connection_details $final_row $status_start_col $status_width "$POD_NAME" "$PORT_FORWARD_PID" $claude_selected
    fi
    
    # Wait for user
    local prompt_row=$((box_height + 5))
    
    # Clear the entire prompt area (both lines)
    for ((r=prompt_row; r<=prompt_row+1; r++)); do
        tput cup $r 0
        tput el
    done
    
    # Show the final prompt
    tput cup $prompt_row 4
    printf "Press %bENTER%b to return to terminal: " "$LOG_SUCCESS_STYLE" "$STYLE_RESET"
    read -r

    # Clean up and return to prompt
    tput cnorm
    stty echo
    clear
    
    # Display simplified connection instructions at terminal
    if [[ $all_success == true ]]; then
        success "=== AI DevKit Deployment Complete ==="
        echo ""
        style_line "$LOG_SUCCESS_STYLE" "Port forwarding is active (PID: $PORT_FORWARD_PID)"
        echo ""
        style_line "$LOG_INFO_STYLE" "SSH: ssh devuser@localhost -p 2222 (password: devuser)"
        style_line "$LOG_INFO_STYLE" "File Manager: http://localhost:8090 (admin/admin)"
        
        if [[ $claude_selected == true ]]; then
            style_line "$LOG_INFO_STYLE" "Claude Code: Run 'claude' after SSH login"
        fi
        
        echo ""
        style_line "$COLOR_GRAY" "To stop port forwarding: kill $PORT_FORWARD_PID"
        style_line "$COLOR_GRAY" "Build log: $LOG_FILE"
    else
        error "Deployment failed - check $LOG_FILE for details"
    fi
}

# Run main
main "$@"
