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
# THEME SYSTEM
# ============================================================================

# Base colors
readonly COLOR_BLACK='\033[0;30m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[0;37m'
readonly COLOR_GRAY='\033[0;90m'

# Bright colors
readonly COLOR_BRIGHT_RED='\033[0;91m'
readonly COLOR_BRIGHT_GREEN='\033[0;92m'
readonly COLOR_BRIGHT_YELLOW='\033[0;93m'
readonly COLOR_BRIGHT_BLUE='\033[0;94m'
readonly COLOR_BRIGHT_MAGENTA='\033[0;95m'
readonly COLOR_BRIGHT_CYAN='\033[0;96m'
readonly COLOR_BRIGHT_WHITE='\033[0;97m'

# Styles
readonly STYLE_BOLD='\033[1m'
readonly STYLE_DIM='\033[2m'
readonly STYLE_ITALIC='\033[3m'
readonly STYLE_UNDERLINE='\033[4m'
readonly STYLE_BLINK='\033[5m'
readonly STYLE_REVERSE='\033[7m'
readonly STYLE_RESET='\033[0m'

# Compound styles
readonly BOLD_RED='\033[1;31m'
readonly BOLD_GREEN='\033[1;32m'
readonly BOLD_YELLOW='\033[1;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly BOLD_MAGENTA='\033[1;35m'
readonly BOLD_CYAN='\033[1;36m'
readonly BOLD_WHITE='\033[1;37m'

# Icons
readonly ICON_SELECTED="✓"
readonly ICON_AVAILABLE="○"
readonly ICON_DISABLED="○"
readonly ICON_CURSOR="▸"
readonly ICON_CHECKMARK="✓"
readonly ICON_WARNING="⚠️"
readonly ICON_INFO="ℹ️"
readonly ICON_SUCCESS="✓"

# Box Drawing Characters
readonly BOX_TOP_LEFT="┌"
readonly BOX_TOP_RIGHT="┐"
readonly BOX_BOTTOM_LEFT="└"
readonly BOX_BOTTOM_RIGHT="┘"
readonly BOX_HORIZONTAL="─"
readonly BOX_VERTICAL="│"
readonly BOX_TITLE_LEFT="┤"
readonly BOX_TITLE_RIGHT="├"
readonly BOX_SEPARATOR="━"

# Default theme values (will be overridden by load_theme)
MENU_BORDER_COLOR="$COLOR_BLUE"
MENU_TITLE_STYLE="$BOLD_YELLOW"
MENU_CATEGORY_STYLE="$COLOR_GREEN"
MENU_CURSOR_COLOR="$COLOR_BRIGHT_BLUE"
MENU_SELECTED_STYLE="$COLOR_BRIGHT_GREEN"
MENU_DISABLED_COLOR="$COLOR_GRAY"
MENU_WARNING_COLOR="$COLOR_YELLOW"
MENU_HINT_STYLE="$BOLD_YELLOW"
MENU_PAGE_INDICATOR_STYLE="$BOLD_YELLOW"
MENU_INSTRUCTION_KEY_STYLE="$COLOR_YELLOW"
MENU_INSTRUCTION_TEXT_STYLE="$STYLE_RESET"

SUMMARY_BORDER_COLOR="$COLOR_BLUE"
SUMMARY_TITLE_STYLE="$BOLD_YELLOW"
SUMMARY_SECTION_STYLE="$BOLD_WHITE"
SUMMARY_CHECKMARK_COLOR="$COLOR_GREEN"
SUMMARY_CATEGORY_STYLE="$COLOR_BLUE"
SUMMARY_ITEM_COLOR="$COLOR_WHITE"
SUMMARY_COUNT_STYLE="$COLOR_GREEN"

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
            MENU_BORDER_COLOR="$COLOR_GRAY"
            MENU_TITLE_STYLE="$BOLD_CYAN"
            MENU_CATEGORY_STYLE="$COLOR_MAGENTA"
            MENU_CURSOR_COLOR="$COLOR_CYAN"
            MENU_SELECTED_STYLE="$COLOR_BRIGHT_CYAN"
            MENU_HINT_STYLE="$COLOR_BRIGHT_YELLOW"
            SUMMARY_BORDER_COLOR="$COLOR_GRAY"
            SUMMARY_CATEGORY_STYLE="$COLOR_MAGENTA"
            ;;
        "matrix")
            # Matrix theme - green on black
            MENU_BORDER_COLOR="$COLOR_GREEN"
            MENU_TITLE_STYLE="$BOLD_GREEN"
            MENU_CATEGORY_STYLE="$COLOR_BRIGHT_GREEN"
            MENU_CURSOR_COLOR="$BOLD_GREEN"
            MENU_SELECTED_STYLE="$BOLD_GREEN"
            MENU_DISABLED_COLOR="$COLOR_GREEN"
            MENU_WARNING_COLOR="$COLOR_BRIGHT_GREEN"
            MENU_HINT_STYLE="$BOLD_GREEN"
            MENU_PAGE_INDICATOR_STYLE="$COLOR_BRIGHT_GREEN"
            MENU_INSTRUCTION_KEY_STYLE="$BOLD_GREEN"
            SUMMARY_BORDER_COLOR="$COLOR_GREEN"
            SUMMARY_TITLE_STYLE="$BOLD_GREEN"
            SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_GREEN"
            SUMMARY_CHECKMARK_COLOR="$BOLD_GREEN"
            LOG_SUCCESS_STYLE="$BOLD_GREEN"
            LOG_WARNING_STYLE="$COLOR_BRIGHT_GREEN"
            LOG_INFO_STYLE="$COLOR_GREEN"
            ;;
        "ocean")
            # Ocean theme - blues and cyans
            MENU_BORDER_COLOR="$COLOR_CYAN"
            MENU_TITLE_STYLE="$BOLD_CYAN"
            MENU_CATEGORY_STYLE="$COLOR_BRIGHT_BLUE"
            MENU_CURSOR_COLOR="$COLOR_BRIGHT_CYAN"
            MENU_SELECTED_STYLE="$BOLD_CYAN"
            MENU_HINT_STYLE="$COLOR_BRIGHT_CYAN"
            SUMMARY_BORDER_COLOR="$COLOR_CYAN"
            SUMMARY_TITLE_STYLE="$BOLD_CYAN"
            SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_BLUE"
            LOG_INFO_STYLE="$BOLD_BLUE"
            ;;
        "minimal")
            # Minimal theme - mostly white/gray
            MENU_BORDER_COLOR="$COLOR_GRAY"
            MENU_TITLE_STYLE="$BOLD_WHITE"
            MENU_CATEGORY_STYLE="$COLOR_WHITE"
            MENU_CURSOR_COLOR="$BOLD_WHITE"
            MENU_SELECTED_STYLE="$BOLD_WHITE"
            MENU_DISABLED_COLOR="$COLOR_GRAY"
            MENU_WARNING_COLOR="$COLOR_WHITE"
            MENU_HINT_STYLE="$COLOR_WHITE"
            MENU_PAGE_INDICATOR_STYLE="$COLOR_WHITE"
            MENU_INSTRUCTION_KEY_STYLE="$BOLD_WHITE"
            SUMMARY_BORDER_COLOR="$COLOR_GRAY"
            SUMMARY_TITLE_STYLE="$BOLD_WHITE"
            SUMMARY_CATEGORY_STYLE="$COLOR_WHITE"
            SUMMARY_CHECKMARK_COLOR="$BOLD_WHITE"
            LOG_SUCCESS_STYLE="$BOLD_WHITE"
            LOG_WARNING_STYLE="$COLOR_WHITE"
            LOG_INFO_STYLE="$COLOR_GRAY"
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

# Function to display component selection menu
select_components() {
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
            components_data+="$line"$'\n'
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
    local cart_width=$((term_width / 2 - 2))
    local content_height=$((term_height - 10))
    local catalog_page=0 cart_page=0
    
    # Calculate pagination
    local page_boundaries=()
    page_boundaries+=(0)
    
    local current_page_rows=0
    local last_category=""
    
    for idx in "${!ids[@]}"; do
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
            page_boundaries+=($idx)
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
    
    # Function to check if a group has items in cart
    has_group_in_cart() {
        local check_group=$1
        for j in "${!groups[@]}"; do
            [[ "${groups[$j]}" == "$check_group" && "${in_cart[$j]}" == true ]] && return 0
        done
        return 1
    }
    
    # Check if requirements are met
    requirements_met() {
        local item_requires=$1
        [[ -z "$item_requires" ]] && return 0
        [[ "$item_requires" == "[]" ]] && return 0
        
        # Split by space for multiple requirements
        for req in $item_requires; do
            has_group_in_cart "$req" || return 1
        done
        return 0
    }
    
    # Function to add/remove item from cart
    toggle_cart_item() {
        local index=$1
        local action=$2
        
        # Bounds checking
        if [[ $index -lt 0 ]] || [[ $index -ge ${#ids[@]} ]]; then
            return 1
        fi
        
        if [[ "$action" == "add" ]]; then
            # Check requirements
            if [[ -n "${requires[$index]}" ]] && [[ "${requires[$index]}" != "[]" ]] && ! requirements_met "${requires[$index]}"; then
                hint_message="${ICON_WARNING}  Requires: ${requires[$index]}"
                hint_timer=30
                return 1
            fi
            
            # Handle mutually exclusive groups
            for j in "${!groups[@]}"; do
                if [[ "${groups[$j]}" == "${groups[$index]}" ]] && [[ $j -ne $index ]] && [[ "${in_cart[$j]}" == true ]]; then
                    in_cart[$j]=false
                    hint_message="${ICON_INFO}  Replaced ${names[$j]} with ${names[$index]}"
                    hint_timer=30
                fi
            done
            
            in_cart[$index]=true
            [[ -z "$hint_message" ]] && hint_message="${ICON_SUCCESS} Added ${names[$index]} to stack" && hint_timer=20
        else
            in_cart[$index]=false
            
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
                hint_message="${ICON_SUCCESS} Removed ${names[$index]} from cart"
                hint_timer=20
            fi
        fi
    }
    
    # Function to draw a box
    draw_box() {
        local x=$1 y=$2 width=$3 height=$4 title=$5 bottom_text=$6
        
        tput cup $y $x
        printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_TOP_LEFT" "$STYLE_RESET"
        for ((i=0; i<width-2; i++)); do 
            printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
        done
        printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_TOP_RIGHT" "$STYLE_RESET"
        
        if [[ -n "$title" ]]; then
            local title_len=${#title}
            local title_pos=$(( (width - title_len - 2) / 2 ))
            tput cup $y $((x + title_pos))
            printf "%b%s%b %b%s%b %b%s%b" \
                "$MENU_BORDER_COLOR" "$BOX_TITLE_LEFT" "$STYLE_RESET" \
                "$MENU_TITLE_STYLE" "$title" "$STYLE_RESET" \
                "$MENU_BORDER_COLOR" "$BOX_TITLE_RIGHT" "$STYLE_RESET"
        fi
        
        for ((i=1; i<height-1; i++)); do
            tput cup $((y + i)) $x
            printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_VERTICAL" "$STYLE_RESET"
            tput cup $((y + i)) $((x + width - 1))
            printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_VERTICAL" "$STYLE_RESET"
        done
        
        tput cup $((y + height - 1)) $x
        printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_BOTTOM_LEFT" "$STYLE_RESET"
        
        if [[ -n "$bottom_text" ]]; then
            local text_len=${#bottom_text}
            local center_pos=$(( (width - text_len - 4) / 2 ))
            
            for ((i=0; i<center_pos; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
            done
            printf " %b%s%b " "$MENU_PAGE_INDICATOR_STYLE" "$bottom_text" "$STYLE_RESET"
            for ((i=0; i<width-center_pos-text_len-6; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
            done
        else
            for ((i=0; i<width-2; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
            done
        fi
        
        printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_BOTTOM_RIGHT" "$STYLE_RESET"
    }
    
    # Function to get display name for category
    get_category_display_name() {
        local cat=$1
        for i in "${!categories[@]}"; do
            if [[ "${categories[$i]}" == "$cat" ]]; then
                echo "${category_names[$i]}"
                return
            fi
        done
        echo "$cat"
    }
    
    # Function to render catalog items for current page
    render_catalog() {
        local start_idx=${page_boundaries[$catalog_page]}
        local end_idx=$total_items
        
        if [[ $((catalog_page + 1)) -lt ${#page_boundaries[@]} ]]; then
            end_idx=${page_boundaries[$((catalog_page + 1))]}
        fi
        
        local display_row=5
        local last_category=""
        local first_visible_idx=-1
        local last_visible_idx=-1
        
        # Clear catalog area
        for ((row=5; row<content_height+5; row++)); do
            tput cup $row 0
            printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_VERTICAL" "$STYLE_RESET"
            for ((col=1; col<catalog_width-1; col++)); do
                printf " "
            done
            printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_VERTICAL" "$STYLE_RESET"
        done
        
        display_row=5
        last_category=""
        
        for ((idx=start_idx; idx<end_idx; idx++)); do
            [[ $display_row -ge $((content_height + 5)) ]] && break
            
            local item_category="${component_categories[$idx]}"
            local display_name=$(get_category_display_name "$item_category")
            
            # Category headers
            if [[ "$item_category" != "$last_category" ]]; then
                tput cup $display_row 2
                printf "%b%s%b" "$MENU_CATEGORY_STYLE" "$display_name" "$STYLE_RESET"
                last_category="$item_category"
                ((display_row++))
                [[ $display_row -ge $((content_height + 5)) ]] && break
            fi
            
            # Render item
            if [[ $display_row -lt $((content_height + 5)) ]]; then
                [[ $first_visible_idx -eq -1 ]] && first_visible_idx=$idx
                last_visible_idx=$idx
                
                tput cup $display_row 2
                
                # Cursor
                if [[ $view == "catalog" && $idx -eq $current ]]; then
                    printf "%b%s%b " "$MENU_CURSOR_COLOR" "$ICON_CURSOR" "$STYLE_RESET"
                else
                    printf "  "
                fi
                
                # Check availability
                local available=true status="" status_color=""
                
                if [[ "${in_cart[$idx]}" == true ]]; then
                    printf "%b%s%b " "$MENU_SELECTED_STYLE" "$ICON_SELECTED" "$STYLE_RESET"
                    status="(in stack)"
                    status_color="$MENU_SELECTED_STYLE"
                elif has_group_in_cart "${groups[$idx]}"; then
                    printf "%b%s%b " "$MENU_DISABLED_COLOR" "$ICON_DISABLED" "$STYLE_RESET"
                    available=false
                elif [[ -n "${requires[$idx]}" ]] && [[ "${requires[$idx]}" != "[]" ]] && ! requirements_met "${requires[$idx]}"; then
                    printf "%b%s%b " "$MENU_WARNING_COLOR" "$ICON_AVAILABLE" "$STYLE_RESET"
                    status="* ${requires[$idx]} required"
                    status_color="$MENU_WARNING_COLOR"
                else
                    printf "%s " "$ICON_AVAILABLE"
                fi
                
                # Item name
                if [[ $available == true || "${in_cart[$idx]}" == true ]]; then
                    printf "%s" "${names[$idx]}"
                else
                    printf "%b%s%b" "$MENU_DISABLED_COLOR" "${names[$idx]}" "$STYLE_RESET"
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
        
        catalog_first_visible=$first_visible_idx
        catalog_last_visible=$last_visible_idx
        
        # Page indicator
        if [[ $total_pages -gt 1 ]]; then
            local page_text="Page $((catalog_page + 1))/$total_pages"
            local text_len=${#page_text}
            local center_pos=$(( (catalog_width - text_len - 4) / 2 ))
            
            tput cup $((content_height + 5)) 0
            printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_BOTTOM_LEFT" "$STYLE_RESET"
            
            for ((i=0; i<center_pos; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
            done
            printf " %b%s%b " "$MENU_PAGE_INDICATOR_STYLE" "$page_text" "$STYLE_RESET"
            
            local remaining=$((catalog_width - center_pos - text_len - 4))
            for ((i=0; i<remaining; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
            done
            
            printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_BOTTOM_RIGHT" "$STYLE_RESET"
        fi
    }

    # Function to render cart items
    render_cart() {
        local display_row=5
        local cart_items_array=()
        
        # Collect cart items
        for idx in "${!in_cart[@]}"; do
            [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
        done
        
        local cart_count=${#cart_items_array[@]}
        
        # Clear cart area
        for ((row=5; row<content_height+5; row++)); do
            tput cup $row $((catalog_width + 4))
            printf "%-$((cart_width-4))s" " "
        done
        
        tput cup $display_row $((catalog_width + 4))
        
        # Always show base components
        printf "%b%d selected + base components:%b" "$SUMMARY_COUNT_STYLE" "$cart_count" "$STYLE_RESET"
        ((display_row++))
        
        # Show base components first
        ((display_row++))
        if [[ $display_row -lt $((content_height + 5)) ]]; then
            tput cup $display_row $((catalog_width + 4))
            printf "%b%s Base Development Tools %s%b" "$SUMMARY_CATEGORY_STYLE" "$BOX_SEPARATOR" "$BOX_SEPARATOR" "$STYLE_RESET"
            ((display_row++))
        fi
        
        # Base components list (updated to include SSH)
        local base_components=(
            "• Filebrowser (port 8090)"
            "• Git"
            "• GitHub CLI (gh)"
            "• Microsoft TUI Test"
            "• Node.js 20.18.0"
            "• SSH Server (port 2222)"
        )
        
        for base_comp in "${base_components[@]}"; do
            if [[ $display_row -lt $((content_height + 5)) ]]; then
                tput cup $display_row $((catalog_width + 4))
                printf "  %s" "$base_comp"
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
                            if [[ $display_row -lt $((content_height + 5)) ]]; then
                                tput cup $display_row $((catalog_width + 4))
                                printf "%b%s %s %s%b" "$SUMMARY_CATEGORY_STYLE" "$BOX_SEPARATOR" "$category_display" "$BOX_SEPARATOR" "$STYLE_RESET"
                                ((display_row++))
                                category_has_items=true
                            fi
                        fi
                        
                        if [[ $display_row -lt $((content_height + 5)) ]]; then
                            tput cup $display_row $((catalog_width + 4))
                            
                            # Cursor
                            if [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]]; then
                                printf "%b%s%b " "$MENU_CURSOR_COLOR" "$ICON_CURSOR" "$STYLE_RESET"
                            else
                                printf "  "
                            fi
                            
                            printf "• %s" "${names[$idx]}"
                            
                            # Remove hint
                            if [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]]; then
                                printf " %b[DEL to remove]%b" "$LOG_ERROR_STYLE" "$STYLE_RESET"
                            fi
                            
                            ((display_row++))
                        fi
                        ((cart_display_count++))
                    fi
                done
            done
        fi
    }
    
    # Main display loop
    while true; do
        # Only clear screen on first draw
        if [[ $screen_initialized == false ]]; then
            clear
            
            # Title
            local title="AI DevKit Pod Configurator"
            local title_len=${#title}
            local title_pos=$(( (term_width - title_len) / 2 ))
            
            tput cup 0 0
            for ((i=0; i<term_width; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_SEPARATOR" "$STYLE_RESET"
            done
            
            tput cup 1 $title_pos
            printf "%b%s%b" "$MENU_TITLE_STYLE" "$title" "$STYLE_RESET"
            
            tput cup 2 0
            for ((i=0; i<term_width; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_SEPARATOR" "$STYLE_RESET"
            done
            
            echo ""
            draw_box 0 4 $catalog_width $((content_height + 2)) "Available Components"
            draw_box $((catalog_width + 2)) 4 $cart_width $((content_height + 2)) "Build Stack"
            
            # Instructions
            tput cup $((term_height - 2)) 0
            for ((i=0; i<term_width; i++)); do 
                printf "%b%s%b" "$MENU_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
            done
            
            screen_initialized=true
        fi
        
        # Handle cursor positioning for page changes
        if [[ -n "$position_cursor_after_render" ]]; then
            render_catalog
            
            if [[ "$position_cursor_after_render" == "first" ]]; then
                current=$catalog_first_visible
            elif [[ "$position_cursor_after_render" == "last" ]]; then
                current=$catalog_last_visible
            fi
            position_cursor_after_render=""
            
            render_catalog
            last_catalog_page=$catalog_page
            last_current=$current
        elif [[ $last_catalog_page != $catalog_page || $last_view != $view || $force_catalog_update == true ]]; then
            render_catalog
            last_catalog_page=$catalog_page
            force_catalog_update=false
        elif [[ $last_current != $current && $view == "catalog" ]]; then
            # Optimized cursor movement
            if [[ $current -ge $catalog_first_visible && $current -le $catalog_last_visible && 
                  $last_current -ge $catalog_first_visible && $last_current -le $catalog_last_visible ]]; then
                
                # Function to calculate screen row for item
                get_screen_row_for_item() {
                    local target_idx=$1
                    local row=5
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
                
                # Update cursor positions
                local old_screen_row=$(get_screen_row_for_item $last_current)
                local new_screen_row=$(get_screen_row_for_item $current)
                
                tput cup $old_screen_row 2
                printf "  "
                
                tput cup $new_screen_row 2
                printf "%b%s%b " "$MENU_CURSOR_COLOR" "$ICON_CURSOR" "$STYLE_RESET"
            else
                render_catalog
            fi
        fi
        
        if [[ $last_cart_page != $cart_page || $last_view != $view || $last_cart_cursor != $cart_cursor || $force_cart_update == true ]]; then
            render_cart
            last_cart_page=$cart_page
            force_cart_update=false
        fi
        
        # Update instructions if view changed
        if [[ $last_view != $view ]]; then
            tput cup $((term_height - 1)) 0
            tput el
            if [[ $view == "catalog" ]]; then
                printf "%b↑↓/jk:%b Navigate  %b←→/hl:%b Page  %bSPACE:%b Add to stack  %bTAB:%b Switch to stack  %bENTER:%b Build  %bq:%b Cancel" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE"
            else
                printf "%b↑↓/jk:%b Navigate  %bDEL/d:%b Remove  %bTAB:%b Switch to catalog  %bENTER:%b Build  %bq:%b Cancel" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE" \
                    "$MENU_INSTRUCTION_KEY_STYLE" "$MENU_INSTRUCTION_TEXT_STYLE"
            fi
        fi
        
        # Display hint message
        if [[ $hint_timer -gt 0 ]]; then
            tput cup 3 0
            tput el
            local hint_pos=$(( (term_width - ${#hint_message}) / 2 ))
            tput cup 3 $hint_pos
            printf "%b%s%b" "$MENU_HINT_STYLE" "$hint_message" "$STYLE_RESET"
            ((hint_timer--))
        elif [[ $hint_timer -eq 0 && -n "$hint_message" ]]; then
            tput cup 3 0
            tput el
            hint_message=""
        fi
        
        # Save state
        last_current=$current
        last_cart_cursor=$cart_cursor
        last_view=$view
        
        # Read key
        IFS= read -rsn1 key
        
        # Debug: Uncomment to see raw key codes
        # if [[ -n "$key" ]]; then
        #     hint_message="DEBUG: Key pressed: $(printf %q "$key") ($(printf '%02x' "'$key"))"
        #     hint_timer=30
        # fi
        
        # Handle input
        if [[ $key == $'\e' ]]; then
            # Read more characters for escape sequences
            read -rsn1 bracket
            if [[ $bracket == '[' ]]; then
                # CSI sequence - read the rest
                read -rsn1 char1
                
                # Check if we need to read more characters
                case "$char1" in
                    '3') # Possible DELETE key sequence
                        read -rsn1 char2
                        if [[ $char2 == '~' ]]; then
                            # DELETE key confirmed
                            if [[ $view == "cart" ]]; then
                                local cart_items_array=()
                                for idx in "${!in_cart[@]}"; do
                                    [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                                done
                                
                                if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                                    hint_message="No items in cart to remove"
                                    hint_timer=30
                                elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                                    local item_idx=${cart_items_array[$cart_cursor]}
                                    
                                    toggle_cart_item $item_idx "remove"
                                    
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
                        fi
                        ;;
                    'A') # Up arrow
                        if [[ $view == "catalog" ]]; then
                            if [[ $current -eq $catalog_first_visible ]] && [[ $catalog_page -gt 0 ]]; then
                                ((catalog_page--))
                                position_cursor_after_render="last"
                            elif ((current > 0)); then
                                ((current--))
                            fi
                        else
                            ((cart_cursor > 0)) && ((cart_cursor--))
                        fi
                        ;;
                    'B') # Down arrow
                        if [[ $view == "catalog" ]]; then
                            if [[ $current -eq $catalog_last_visible ]] && [[ $catalog_page -lt $((total_pages - 1)) ]]; then
                                ((catalog_page++))
                                position_cursor_after_render="first"
                            elif ((current < total_items - 1)); then
                                ((current++))
                            fi
                        else
                            local cart_items_count=0
                            for ic in "${in_cart[@]}"; do [[ $ic == true ]] && ((cart_items_count++)); done
                            ((cart_cursor < cart_items_count - 1)) && ((cart_cursor++))
                        fi
                        ;;
                    'C') # Right arrow
                        if [[ $view == "catalog" && $catalog_page -lt $((total_pages - 1)) ]]; then
                            ((catalog_page++))
                            position_cursor_after_render="first"
                        fi
                        ;;
                    'D') # Left arrow
                        if [[ $view == "catalog" && $catalog_page -gt 0 ]]; then
                            ((catalog_page--))
                            position_cursor_after_render="first"
                        fi
                        ;;
                    'P') # Alternative DELETE on some terminals
                        if [[ $view == "cart" ]]; then
                            local cart_items_array=()
                            for idx in "${!in_cart[@]}"; do
                                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                            done
                            
                            if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                                hint_message="No items in cart to remove"
                                hint_timer=30
                            elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                                local item_idx=${cart_items_array[$cart_cursor]}
                                
                                toggle_cart_item $item_idx "remove"
                                
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
                        if [[ $view == "catalog" ]]; then
                            if [[ $current -eq $catalog_first_visible ]] && [[ $catalog_page -gt 0 ]]; then
                                ((catalog_page--))
                                position_cursor_after_render="last"
                            elif ((current > 0)); then
                                ((current--))
                            fi
                        else
                            ((cart_cursor > 0)) && ((cart_cursor--))
                        fi
                        ;;
                    'B') # Down arrow (alternative)
                        if [[ $view == "catalog" ]]; then
                            if [[ $current -eq $catalog_last_visible ]] && [[ $catalog_page -lt $((total_pages - 1)) ]]; then
                                ((catalog_page++))
                                position_cursor_after_render="first"
                            elif ((current < total_items - 1)); then
                                ((current++))
                            fi
                        else
                            local cart_items_count=0
                            for ic in "${in_cart[@]}"; do [[ $ic == true ]] && ((cart_items_count++)); done
                            ((cart_cursor < cart_items_count - 1)) && ((cart_cursor++))
                        fi
                        ;;
                    'C') # Right arrow (alternative)
                        if [[ $view == "catalog" && $catalog_page -lt $((total_pages - 1)) ]]; then
                            ((catalog_page++))
                            position_cursor_after_render="first"
                        fi
                        ;;
                    'D') # Left arrow (alternative)
                        if [[ $view == "catalog" && $catalog_page -gt 0 ]]; then
                            ((catalog_page--))
                            position_cursor_after_render="first"
                        fi
                        ;;
                esac
            fi
        elif [[ -z "$key" ]]; then
            break  # Enter key
        elif [[ "$key" == $'\t' ]]; then
            view=$([[ $view == "catalog" ]] && echo "cart" || echo "catalog")
            [[ $view == "cart" ]] && cart_cursor=0
        elif [[ "$key" == " " && $view == "catalog" ]]; then
            if [[ $current -ge 0 ]] && [[ $current -lt ${#ids[@]} ]]; then
                if [[ "${in_cart[$current]}" == true ]]; then
                    toggle_cart_item $current "remove"
                else
                    toggle_cart_item $current "add"
                fi
                force_catalog_update=true
                force_cart_update=true
            fi
        elif [[ "$key" =~ ^[jJ]$ ]]; then
            if [[ $view == "catalog" ]]; then
                if [[ $current -eq $catalog_last_visible ]] && [[ $catalog_page -lt $((total_pages - 1)) ]]; then
                    ((catalog_page++))
                    position_cursor_after_render="first"
                elif ((current < total_items - 1)); then
                    ((current++))
                fi
            else
                local cart_items_count=0
                for ic in "${in_cart[@]}"; do [[ $ic == true ]] && ((cart_items_count++)); done
                ((cart_cursor < cart_items_count - 1)) && ((cart_cursor++))
            fi
        elif [[ "$key" =~ ^[kK]$ ]]; then
            if [[ $view == "catalog" ]]; then
                if [[ $current -eq $catalog_first_visible ]] && [[ $catalog_page -gt 0 ]]; then
                    ((catalog_page--))
                    position_cursor_after_render="last"
                elif ((current > 0)); then
                    ((current--))
                fi
            else
                ((cart_cursor > 0)) && ((cart_cursor--))
            fi
        elif [[ "$key" =~ ^[hH]$ && $view == "catalog" ]]; then
            if [[ $catalog_page -gt 0 ]]; then
                ((catalog_page--))
                position_cursor_after_render="first"
            fi
        elif [[ "$key" =~ ^[lL]$ && $view == "catalog" ]]; then
            if [[ $catalog_page -lt $((total_pages - 1)) ]]; then
                ((catalog_page++))
                position_cursor_after_render="first"
            fi
        elif [[ "$key" =~ ^[dD]$ && $view == "cart" ]]; then  # 'd' key for delete
            local cart_items_array=()
            for idx in "${!in_cart[@]}"; do
                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
            done
            
            if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                hint_message="No items in cart to remove"
                hint_timer=30
            elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                local item_idx=${cart_items_array[$cart_cursor]}
                
                toggle_cart_item $item_idx "remove"
                
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
        elif [[ "$key" == $'\x7f' && $view == "cart" ]]; then  # Backspace key (0x7F)
            local cart_items_array=()
            for idx in "${!in_cart[@]}"; do
                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
            done
            
            if [[ ${#cart_items_array[@]} -eq 0 ]]; then
                hint_message="No items in cart to remove"
                hint_timer=30
            elif [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                local item_idx=${cart_items_array[$cart_cursor]}
                
                toggle_cart_item $item_idx "remove"
                
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
    done   

    tput cnorm
    stty echo
    clear
    
    # Build final selections - Summary Screen
    local term_width=$(tput cols)
    
    # Header
    tput cup 0 0
    for ((i=0; i<term_width; i++)); do 
        printf "%b%s%b" "$SUMMARY_BORDER_COLOR" "$BOX_SEPARATOR" "$STYLE_RESET"
    done
    
    local title="AI DevKit Pod Configurator - Deployment Manifest"
    local title_len=${#title}
    local title_pos=$(( (term_width - title_len) / 2 ))
    tput cup 1 $title_pos
    printf "%b%s%b" "$SUMMARY_TITLE_STYLE" "$title" "$STYLE_RESET"
    
    tput cup 2 0
    for ((i=0; i<term_width; i++)); do 
        printf "%b%s%b" "$SUMMARY_BORDER_COLOR" "$BOX_SEPARATOR" "$STYLE_RESET"
    done
    
    echo ""
    echo ""
    
    # Always show base components first
    style_line "$SUMMARY_SECTION_STYLE" "Base Development Tools (included in all builds):"
    echo ""
    style_line "$SUMMARY_CATEGORY_STYLE" "  ${BOX_SEPARATOR} Base Development Tools ${BOX_SEPARATOR}"
    echo -e "    ${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} Filebrowser (port 8090)"
    echo -e "    ${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} Git"
    echo -e "    ${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} GitHub CLI (gh)"
    echo -e "    ${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} Microsoft TUI Test"
    echo -e "    ${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} Node.js 20.18.0" 
    echo -e "    ${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} SSH Server (port 2222)"
    
    # Count selections
    local selection_count=0
    for i in "${!in_cart[@]}"; do
        [[ "${in_cart[$i]}" == true ]] && ((selection_count++))
    done
    
    if [[ $selection_count -eq 0 ]]; then
        echo ""
        style_line "$LOG_WARNING_STYLE" "No additional components selected"
    else
        echo ""
        style_line "$SUMMARY_COUNT_STYLE" "Additional components selected: $selection_count"
        
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
                    if [[ $category_has_items == false ]]; then
                        echo ""
                        style_line "$SUMMARY_CATEGORY_STYLE" "  ${BOX_SEPARATOR} ${category_display} ${BOX_SEPARATOR}"
                        category_has_items=true
                    fi
                    
                    echo -e "    ${SUMMARY_CHECKMARK_COLOR}${ICON_CHECKMARK}${STYLE_RESET} ${names[$i]}"
                    
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
    
    echo ""
    echo ""
    
    # Separator
    for ((i=0; i<term_width; i++)); do 
        printf "%b%s%b" "$SUMMARY_BORDER_COLOR" "$BOX_HORIZONTAL" "$STYLE_RESET"
    done
    echo ""
    
    log "Ready to build with this configuration?"
    printf "Press %bENTER%b to continue or %b'q'%b to quit: " \
        "$LOG_SUCCESS_STYLE" "$STYLE_RESET" \
        "$LOG_ERROR_STYLE" "$STYLE_RESET"
    read -r CONFIRM
    
    [[ "$CONFIRM" =~ ^[qQ]$ ]] && log "Build cancelled." && exit 0
    
    set -e
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
                    inject_commands+="COPY $source $destination"$'\n'
                    if [[ -n "$permissions" ]]; then
                        inject_commands+="RUN chmod $permissions $destination"$'\n'
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
        inject_commands+="COPY $source $destination"$'\n'
        if [[ -n "$permissions" ]]; then
            inject_commands+="RUN chmod $permissions $destination"$'\n'
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
                entrypoint_content+="${line:2}"$'\n'
            elif [[ -z "$line" ]]; then
                # Preserve empty lines
                entrypoint_content+=$'\n'
            fi
        fi
    done < "$yaml_file"
    
    # Trim trailing newlines
    entrypoint_content=$(echo -n "$entrypoint_content" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
    
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
                dockerfile_content+="${line:4}"$'\n'
            else
                # Handle empty lines or lines with different indentation
                dockerfile_content+="$line"$'\n'
            fi
        elif [[ $in_nexus == true ]]; then
            # For nexus content, preserve it as-is after removing YAML indent
            if [[ "$line" =~ ^"    " ]]; then
                nexus_content+="${line:4}"$'\n'
            fi
        fi
    done < "$yaml_file"
    
    # Combine dockerfile and nexus content if applicable
    local full_content="$dockerfile_content"
    if [[ -n "$nexus_content" ]]; then
        # The nexus_config should already be properly formatted in the YAML
        # Just wrap it in RUN
        full_content+=$'\n'"# Nexus configuration"$'\n'"RUN ${nexus_content}"
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
    
    # Create placeholder files if they do not exist (for when no components are selected)
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
            installation_content+=\n'"# From $yaml_file"\n'
            installation_content+="$install_cmds"\n'
        fi
        
        # Extract inject_files directives
        local inject_cmds=$(extract_inject_files_from_yaml "$yaml_file")
        if [[ -n "$inject_cmds" ]]; then
            inject_files_content+=\n'"# Files injected by $component_name"\n'
            inject_files_content+="$inject_cmds"
        fi
        
        # Extract entrypoint setup
        local entrypoint_cmds=$(extract_entrypoint_setup "$yaml_file")
        if [[ -n "$entrypoint_cmds" ]]; then
            entrypoint_setup_content+=\n'"# Setup for $component_name"\n'
            entrypoint_setup_content+="$entrypoint_cmds"\n'
        fi
    done
    
    # Insert installations
    if [[ -n "$installation_content" ]]; then
        echo -e "$installation_content" > "$TEMP_DIR/installations.txt"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/r $TEMP_DIR/installations.txt" "$TEMP_DIR/Dockerfile"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak" "$TEMP_DIR/installations.txt"
    else
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak"
    fi
    
    # Insert file injections before volume declarations
    if [[ -n "$inject_files_content" ]]; then
        echo -e "$inject_files_content" > "$TEMP_DIR/inject_files.txt"
        # Insert before the VOLUME declaration
        sed -i.bak '/^# Set up volume mount points/i\
' "$TEMP_DIR/Dockerfile"
        sed -i.bak "/^# Set up volume mount points/r $TEMP_DIR/inject_files.txt" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak" "$TEMP_DIR/inject_files.txt"
    fi
    
    # Now modify the generated entrypoint.sh with component setup
    if [[ -n "$entrypoint_setup_content" ]]; then
        # Create temporary file with the setup content
        echo -e "$entrypoint_setup_content" > "$TEMP_DIR/entrypoint_setup.txt"
        
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

# Main execution
main() {
    # Initialize log file
    echo "Build started at $(date)" > "$LOG_FILE"
    echo "=================================================================================" >> "$LOG_FILE"
    
    log "=== Starting AI DevKit Pod Configurator ==="
    
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
    
    # Generate SSH host keys
    generate_ssh_host_keys
    
    # Load categories for use in generate_claude_md
    # This is a bit hacky but necessary since we need the category display names
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
    
    # Component selection
    [[ ! "$1" =~ --no-select && ! "$2" =~ --no-select ]] && select_components
    
    # Clean up only AFTER user confirms they want to build
    if [[ -d "$TEMP_DIR" ]]; then
        log "Cleaning up previous build directory..."
        rm -rf "$TEMP_DIR"/*
    fi
    
    # Delete the deployment to ensure fresh container
    log "Removing previous deployment..."
    kubectl delete deployment ai-devkit -n ${NAMESPACE} --ignore-not-found=true >> "$LOG_FILE" 2>&1
    docker rmi ${IMAGE_NAME}:${IMAGE_TAG} >> "$LOG_FILE" 2>&1 || true
    
    # Create base components
    log "Creating custom Dockerfile..."
    echo -e "\nDockerfile generation output:" >> "$LOG_FILE"
    echo "=================================================================================" >> "$LOG_FILE"
    create_custom_dockerfile >> "$LOG_FILE" 2>&1
    
    log "Building Docker image..."
    # Always build from TEMP_DIR since we now generate entrypoint.sh
    cp setup-git.sh "$TEMP_DIR/"
    cp motd-ai-devkit.sh "$TEMP_DIR/"
    cp nodejs-base.md "$TEMP_DIR/"
    cp -r configs "$TEMP_DIR/"
    cp -r templates "$TEMP_DIR/"

    cd "$TEMP_DIR"
    echo "Docker build output:" >> "../$LOG_FILE"
    echo "=================================================================================" >> "../$LOG_FILE"
    if [[ -n "$NEXUS_BUILD_ARGS" ]]; then
        docker build $NEXUS_BUILD_ARGS -t ${IMAGE_NAME}:${IMAGE_TAG} . >> "../$LOG_FILE" 2>&1 || \
            (error "Docker build failed - check $LOG_FILE for details" && exit 1)
    else
        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} . >> "../$LOG_FILE" 2>&1 || \
            (error "Docker build failed - check $LOG_FILE for details" && exit 1)
    fi
    cd ..
    success "Docker image built (detailed log in $LOG_FILE)"
    
    # Deploy
    log "Deploying to Kubernetes..."
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
    
    log "Waiting for deployment..."
    kubectl wait --for=condition=available --timeout=120s deployment/ai-devkit -n ${NAMESPACE} >> "$LOG_FILE" 2>&1
    
    POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=ai-devkit -o jsonpath="{.items[0].metadata.name}")
    
    # Start port forwarding automatically
    log "Setting up port forwarding..."
    pkill -f 'kubectl.*port-forward.*ai-devkit' 2>/dev/null || true
    sleep 1
    kubectl port-forward -n ${NAMESPACE} service/ai-devkit 2222:22 8090:8090 >> "$LOG_FILE" 2>&1 &
    PORT_FORWARD_PID=$!
    sleep 2
    
    # Check if port forwarding is running
    if ! ps -p $PORT_FORWARD_PID > /dev/null 2>&1; then
        error "Port forwarding failed to start - check $LOG_FILE for details"
    fi
    
    success "=== Deployment Complete ==="
    echo ""
    
    [[ "$NEXUS_AVAILABLE" = true ]] && success "Using Nexus proxy for package downloads"
    
    # Simple connection instructions
    style_line "$LOG_SUCCESS_STYLE" "Ready to connect! Port forwarding is active (PID: $PORT_FORWARD_PID)"
    echo ""
    style_line "$LOG_WARNING_STYLE" "1. SSH to your environment:"
    style_line "$LOG_INFO_STYLE" "   ssh devuser@localhost -p 2222"
    printf "   Password: %bdevuser%b (change with 'passwd')\n" "$LOG_WARNING_STYLE" "$STYLE_RESET"
    echo ""
    printf "%b2. Access file manager:%b %bhttp://localhost:8090%b (admin/admin)\n" \
        "$LOG_WARNING_STYLE" "$STYLE_RESET" "$LOG_INFO_STYLE" "$STYLE_RESET"
    echo ""
    
    # Check if Claude Code was selected
    local claude_selected=false
    for id in "${SELECTED_IDS[@]}"; do
        if [[ "$id" == "CLAUDE_CODE" ]]; then
            claude_selected=true
            break
        fi
    done
    
    if [[ $claude_selected == true ]]; then
        printf "%bStart Claude Code:%b %bclaude%b\n" \
            "$LOG_SUCCESS_STYLE" "$STYLE_RESET" "$LOG_WARNING_STYLE" "$STYLE_RESET"
    fi
    
    echo ""
    style_line "$COLOR_GRAY" "Alternative: kubectl exec -it -n ${NAMESPACE} ${POD_NAME} -c ai-devkit -- su - devuser"
    style_line "$COLOR_GRAY" "Stop port forwarding: kill $PORT_FORWARD_PID"
    echo ""
    style_line "$COLOR_GRAY" "Build log saved to: $LOG_FILE"
}

# Run main
main "$@"
