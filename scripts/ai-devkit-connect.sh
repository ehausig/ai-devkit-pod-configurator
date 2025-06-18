#!/bin/bash
# AI DevKit Connection Helper Script
# This script helps you connect to your AI development environment

# Configuration
NAMESPACE="claude-code"
SSH_PORT=2222
FILEBROWSER_PORT=8090

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log() { echo -e "${YELLOW}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Check if kubectl is available
if ! command -#!/bin/bash
# This script requires bash 3.2 or higher
set -e

# Configuration
IMAGE_NAME="claude-code"
IMAGE_TAG="latest"
NAMESPACE="claude-code"
TEMP_DIR=".build-temp"
COMPONENTS_DIR="components"
SSH_KEYS_DIR="$HOME/.claude-code-k8s/ssh-keys"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Utility functions
log() { echo -e "${2:-$YELLOW}$1${NC}"; }
error() { log "Error: $1" "$RED"; exit 1; }
success() { log "$1" "$GREEN"; }
info() { log "$1" "$BLUE"; }

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
        success "✓ Nexus detected at http://localhost:8081"
        return 0
    fi
    return 1
}

# Generate SSH host keys if they don't exist
generate_ssh_host_keys() {
    log "Checking SSH host keys..."
    
    mkdir -p "$SSH_KEYS_DIR"
    
    # Generate keys if they don't exist
    if [ ! -f "$SSH_KEYS_DIR/ssh_host_rsa_key" ]; then
        info "Generating SSH host keys for consistent fingerprints..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEYS_DIR/ssh_host_rsa_key" -N "" -C "ai-devkit-rsa"
        ssh-keygen -t ecdsa -b 521 -f "$SSH_KEYS_DIR/ssh_host_ecdsa_key" -N "" -C "ai-devkit-ecdsa"
        ssh-keygen -t ed25519 -f "$SSH_KEYS_DIR/ssh_host_ed25519_key" -N "" -C "ai-devkit-ed25519"
        success "SSH host keys generated in $SSH_KEYS_DIR"
    else
        success "Using existing SSH host keys from $SSH_KEYS_DIR"
    fi
    
    # Display the fingerprints
    info "SSH host key fingerprints (these will remain constant across deployments):"
    ssh-keygen -lf "$SSH_KEYS_DIR/ssh_host_ed25519_key.pub" | sed 's/^/  /'
    ssh-keygen -lf "$SSH_KEYS_DIR/ssh_host_ecdsa_key.pub" | sed 's/^/  /'
    echo ""
}

# Create SSH host keys secret
create_ssh_host_keys_secret() {
    log "Creating Kubernetes secret for SSH host keys..."
    
    # Delete existing secret if it exists
    kubectl delete secret ssh-host-keys -n ${NAMESPACE} --ignore-not-found=true
    
    # Create secret from files
    kubectl create secret generic ssh-host-keys -n ${NAMESPACE} \
        --from-file=ssh_host_rsa_key="$SSH_KEYS_DIR/ssh_host_rsa_key" \
        --from-file=ssh_host_rsa_key.pub="$SSH_KEYS_DIR/ssh_host_rsa_key.pub" \
        --from-file=ssh_host_ecdsa_key="$SSH_KEYS_DIR/ssh_host_ecdsa_key" \
        --from-file=ssh_host_ecdsa_key.pub="$SSH_KEYS_DIR/ssh_host_ecdsa_key.pub" \
        --from-file=ssh_host_ed25519_key="$SSH_KEYS_DIR/ssh_host_ed25519_key" \
        --from-file=ssh_host_ed25519_key.pub="$SSH_KEYS_DIR/ssh_host_ed25519_key.pub"
    
    success "SSH host keys secret created"
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
    set +e  # Don't exit on error
    
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
    
    # Function to get cart item name from group
    get_group_cart_item() {
        local check_group=$1
        for j in "${!groups[@]}"; do
            if [[ "${groups[$j]}" == "$check_group" && "${in_cart[$j]}" == true ]]; then
                echo "${names[$j]}"
                return
            fi
        done
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
                hint_message="⚠️  Requires: ${requires[$index]}"
                hint_timer=30
                return 1
            fi
            
            # Handle mutually exclusive groups
            if [[ "${groups[$index]}" == *"-version" ]]; then
                for j in "${!groups[@]}"; do
                    if [[ "${groups[$j]}" == "${groups[$index]}" ]] && [[ $j -ne $index ]] && [[ "${in_cart[$j]}" == true ]]; then
                        in_cart[$j]=false
                        hint_message="ℹ️  Replaced ${names[$j]} with ${names[$index]}"
                        hint_timer=30
                    fi
                done
            fi
            
            in_cart[$index]=true
            [[ -z "$hint_message" ]] && hint_message="✓ Added ${names[$index]} to stack" && hint_timer=20
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
                hint_message="⚠️  Also removed dependent items: $dependents"
                hint_timer=40
            else
                hint_message="✓ Removed ${names[$index]} from cart"
                hint_timer=20
            fi
        fi
    }
    
    # Function to draw a box
    draw_box() {
        local x=$1 y=$2 width=$3 height=$4 title=$5 bottom_text=$6
        
        tput cup $y $x
        echo -ne "┌"
        for ((i=0; i<width-2; i++)); do echo -ne "─"; done
        echo -ne "┐"
        
        if [[ -n "$title" ]]; then
            local title_len=${#title}
            local title_pos=$(( (width - title_len - 2) / 2 ))
            tput cup $y $((x + title_pos))
            echo -ne "┤ $title ├"
        fi
        
        for ((i=1; i<height-1; i++)); do
            tput cup $((y + i)) $x; echo -ne "│"
            tput cup $((y + i)) $((x + width - 1)); echo -ne "│"
        done
        
        tput cup $((y + height - 1)) $x
        echo -ne "└"
        
        if [[ -n "$bottom_text" ]]; then
            local text_len=${#bottom_text}
            local center_pos=$(( (width - text_len - 4) / 2 ))
            
            for ((i=0; i<center_pos; i++)); do echo -ne "─"; done
            echo -ne " ${YELLOW}${bottom_text}${NC} "
            for ((i=0; i<width-center_pos-text_len-6; i++)); do echo -ne "─"; done
        else
            for ((i=0; i<width-2; i++)); do echo -ne "─"; done
        fi
        
        echo -ne "┘"
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
            printf "│"
            for ((col=1; col<catalog_width-1; col++)); do
                printf " "
            done
            printf "│"
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
                printf "%b%s%b" "${GREEN}" "$display_name" "${NC}"
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
                    printf "\033[0;34m▸\033[0m "
                else
                    printf "  "
                fi
                
                # Check availability
                local available=true status="" status_color=""
                
                if [[ "${in_cart[$idx]}" == true ]]; then
                    printf "\033[0;32m✓\033[0m "
                    status="(in stack)"
                    status_color="\033[0;32m"
                elif [[ "${groups[$idx]}" == *"-version" ]] && has_group_in_cart "${groups[$idx]}"; then
                    printf "\033[0;90m○\033[0m "
                    available=false
                elif [[ -n "${requires[$idx]}" ]] && [[ "${requires[$idx]}" != "[]" ]] && ! requirements_met "${requires[$idx]}"; then
                    printf "\033[1;33m○\033[0m "
                    status="(needs ${requires[$idx]})"
                    status_color="\033[1;33m"
                else
                    printf "○ "
                fi
                
                # Item name
                if [[ $available == true || "${in_cart[$idx]}" == true ]]; then
                    printf "%s" "${names[$idx]}"
                else
                    printf "\033[0;90m%s\033[0m" "${names[$idx]}"
                fi
                
                # Status
                if [[ -n "$status" ]]; then
                    local name_len=${#names[$idx]}
                    local status_len=${#status}
                    local padding=$((catalog_width - name_len - status_len - 8))
                    if [[ $padding -gt 0 ]]; then
                        tput cuf $padding
                        printf "%b%s\033[0m" "$status_color" "$status"
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
            printf "└"
            
            for ((i=0; i<center_pos; i++)); do printf "─"; done
            printf " \033[1;33m%s\033[0m " "${page_text}"
            
            local remaining=$((catalog_width - center_pos - text_len - 4))
            for ((i=0; i<remaining; i++)); do printf "─"; done
            
            printf "┘"
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
        printf "%b%d selected + base components:%b" "${GREEN}" "$cart_count" "${NC}"
        ((display_row++))
        
        # Show base components first
        ((display_row++))
        if [[ $display_row -lt $((content_height + 5)) ]]; then
            tput cup $display_row $((catalog_width + 4))
            printf "%b━ Base Development Tools ━%b" "${BLUE}" "${NC}"
            ((display_row++))
        fi
        
        # Base components list (updated to include SSH)
        local base_components=(
            "• Git"
            "• GitHub CLI (gh)"
            "• SSH Server"
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
                                printf "%b━ %s ━%b" "${BLUE}" "$category_display" "${NC}"
                                ((display_row++))
                                category_has_items=true
                            fi
                        fi
                        
                        if [[ $display_row -lt $((content_height + 5)) ]]; then
                            tput cup $display_row $((catalog_width + 4))
                            
                            # Cursor
                            [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]] && printf "%b▸%b " "${BLUE}" "${NC}" || printf "  "
                            
                            printf "• %s" "${names[$idx]}"
                            
                            # Remove hint
                            [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]] && printf " %b[DEL to remove]%b" "${RED}" "${NC}"
                            
                            ((display_row++))
                        fi
                        ((cart_display_count++))
                    fi
                done
            done
        else
            # Show message when no additional components selected
            ((display_row++))
            if [[ $display_row -lt $((content_height + 5)) ]]; then
                tput cup $display_row $((catalog_width + 4))
                printf "%b(No additional components selected)%b" "${YELLOW}" "${NC}"
            fi
        fi
    }
    
    # Main display loop
    while true; do
        # Only clear screen on first draw
        if [[ $screen_initialized == false ]]; then
            clear
            
            # Title
            local title="Container Component Configurator"
            local title_len=${#title}
            local title_pos=$(( (term_width - title_len) / 2 ))
            
            tput cup 0 0
            for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}━${NC}"; done
            
            tput cup 1 $title_pos
            echo -ne "${YELLOW}${title}${NC}"
            
            tput cup 2 0
            for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}━${NC}"; done
            
            echo ""
            draw_box 0 4 $catalog_width $((content_height + 2)) "Available Components"
            draw_box $((catalog_width + 2)) 4 $cart_width $((content_height + 2)) "Build Stack"
            
            # Instructions
            tput cup $((term_height - 2)) 0
            for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}─${NC}"; done
            
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
                printf "\033[0;34m▸\033[0m "
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
                echo -ne "${YELLOW}↑↓/jk:${NC} Navigate  ${YELLOW}←→/hl:${NC} Page  ${YELLOW}SPACE:${NC} Add to stack  ${YELLOW}TAB:${NC} Switch to stack  ${YELLOW}ENTER:${NC} Build  ${YELLOW}q:${NC} Cancel"
            else
                echo -ne "${YELLOW}↑↓/jk:${NC} Navigate  ${YELLOW}DEL/d:${NC} Remove  ${YELLOW}TAB:${NC} Switch to catalog  ${YELLOW}ENTER:${NC} Build  ${YELLOW}q:${NC} Cancel"
            fi
        fi
        
        # Display hint message
        if [[ $hint_timer -gt 0 ]]; then
            tput cup 3 0
            tput el
            local hint_pos=$(( (term_width - ${#hint_message}) / 2 ))
            tput cup 3 $hint_pos
            echo -ne "${YELLOW}$hint_message${NC}"
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
        elif [[ "$key" == \x7f' && $view == "cart" ]]; then  # Backspace key (0x7F)
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
    
    # Build final selections
    local term_width=$(tput cols)
    
    # Header
    tput cup 0 0
    for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}━${NC}"; done
    
    local title="Build Configuration Summary"
    local title_len=${#title}
    local title_pos=$(( (term_width - title_len) / 2 ))
    tput cup 1 $title_pos
    echo -ne "${YELLOW}${title}${NC}"
    
    tput cup 2 0
    for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}━${NC}"; done
    
    echo ""
    echo ""
    
    # Always show base components first
    echo -e "${GREEN}Base Development Tools (included in all builds):${NC}"
    echo ""
    echo -e "  ${BLUE}━ Base Development Tools ━${NC}"
    echo -e "    ${GREEN}✓${NC} Git"
    echo -e "    ${GREEN}✓${NC} GitHub CLI (gh)"
    echo -e "    ${GREEN}✓${NC} SSH Server (port 22)"
    
    # Count selections
    local selection_count=0
    for i in "${!in_cart[@]}"; do
        [[ "${in_cart[$i]}" == true ]] && ((selection_count++))
    done
    
    if [[ $selection_count -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}No additional components selected${NC}"
    else
        echo ""
        echo -e "${GREEN}Additional components selected: $selection_count${NC}"
        
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
                        echo -e "  ${BLUE}━ ${category_display} ━${NC}"
                        category_has_items=true
                    fi
                    
                    echo -e "    ${GREEN}✓${NC} ${names[$i]}"
                    
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
    for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}─${NC}"; done
    echo ""
    
    log "Ready to build with this configuration?"
    echo -ne "Press ${GREEN}ENTER${NC} to continue or ${RED}'q'${NC} to quit: "
    read -r CONFIRM
    
    [[ "$CONFIRM" =~ ^[qQ]$ ]] && log "Build cancelled." && exit 0
    
    set -e
}
