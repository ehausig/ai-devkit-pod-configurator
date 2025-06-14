#!/bin/bash
set -e

# Configuration
IMAGE_NAME="claude-code"
IMAGE_TAG="latest"
NAMESPACE="claude-code"
TEMP_DIR=".build-temp"
COMPONENTS_DIR="components"

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
    
    echo "${categories[@]}"
    echo "---SEPARATOR---"
    echo "${category_names[@]}"
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
    local category_names_line=$(echo "$component_data" | sed -n '3p')
    local components_data=$(echo "$component_data" | sed '1,4d')
    
    # Convert to arrays
    IFS=' ' read -ra categories <<< "$categories_line"
    IFS=' ' read -ra category_names <<< "$category_names_line"
    
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
                    printf "\033[0;31m○\033[0m "
                    available=false
                    local existing=$(get_group_cart_item "${groups[$idx]}")
                    status="($existing selected)"
                    status_color="\033[0;31m"
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
                    printf "\033[0;31m%s\033[0m" "${names[$idx]}"
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
        
        # Base components list
        local base_components=(
            "• Node.js 20.18.0"
            "• npm (latest)"
            "• Git"
            "• GitHub CLI (gh)"
            "• Claude Code (@anthropic-ai/claude-code)"
        )
        
        for base_comp in "${base_components[@]}"; do
            if [[ $display_row -lt $((content_height + 5)) ]]; then
                tput cup $display_row $((catalog_width + 4))
                printf "  %b%s%b %b(included)%b" "${GRAY}" "$base_comp" "${NC}" "${GRAY}" "${NC}"
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
        
        # Handle input
        if [[ $key == $'\e' ]]; then
            read -rsn2 key
            case "$key" in
                "[A"|"OA") # Up arrow
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
                "[B"|"OB") # Down arrow
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
                "[D"|"OD") # Left arrow
                    if [[ $view == "catalog" && $catalog_page -gt 0 ]]; then
                        ((catalog_page--))
                        position_cursor_after_render="first"
                    fi
                    ;;
                "[C"|"OC") # Right arrow
                    if [[ $view == "catalog" && $catalog_page -lt $((total_pages - 1)) ]]; then
                        ((catalog_page++))
                        position_cursor_after_render="first"
                    fi
                    ;;
                "[3~") # Delete key
                    if [[ $view == "cart" ]]; then
                        local cart_items_array=()
                        for idx in "${!in_cart[@]}"; do
                            [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
                        done
                        if [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                            toggle_cart_item ${cart_items_array[$cart_cursor]} "remove"
                            local new_count=${#cart_items_array[@]}
                            ((new_count--))
                            [[ $cart_cursor -ge $new_count && $cart_cursor -gt 0 ]] && ((cart_cursor--))
                            force_catalog_update=true
                            force_cart_update=true
                        fi
                    fi
                    ;;
            esac
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
        elif [[ "$key" =~ ^[dD]$ && $view == "cart" ]]; then
            local cart_items_array=()
            for idx in "${!in_cart[@]}"; do
                [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
            done
            if [[ $cart_cursor -lt ${#cart_items_array[@]} ]]; then
                toggle_cart_item ${cart_items_array[$cart_cursor]} "remove"
                local new_count=${#cart_items_array[@]}
                ((new_count--))
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
    
    # Count selections
    local selection_count=0
    for i in "${!in_cart[@]}"; do
        [[ "${in_cart[$i]}" == true ]] && ((selection_count++))
    done
    
    if [[ $selection_count -eq 0 ]]; then
        echo -e "${YELLOW}No additional components selected (base image only)${NC}"
    else
        echo -e "${GREEN}Selected $selection_count components:${NC}"
        echo ""
        
        # Store selections
        SELECTED_YAML_FILES=()
        SELECTED_IDS=()
        SELECTED_NAMES=()
        SELECTED_GROUPS=()
        SELECTED_CATEGORIES=()
        
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

# Global variables for selected items
declare -a SELECTED_YAML_FILES
declare -a SELECTED_IDS
declare -a SELECTED_NAMES
declare -a SELECTED_GROUPS
declare -a SELECTED_CATEGORIES

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
    
    echo -n "$full_content"
}

# Function to generate CLAUDE.md
generate_claude_md() {
    local claude_template="CLAUDE.md.template"
    local claude_output="$TEMP_DIR/CLAUDE.md"
    
    if [[ ! -f "$claude_template" ]]; then
        log "Warning: $claude_template not found, skipping CLAUDE.md generation"
        return
    fi
    
    log "Generating CLAUDE.md from template..."
    
    # Copy template up to marker
    sed '/<!-- ENVIRONMENT_TOOLS_MARKER -->/q' "$claude_template" > "$claude_output"
    
    # Generate tool list
    echo "" >> "$claude_output"
    echo "## Installed Development Environment" >> "$claude_output"
    echo "" >> "$claude_output"
    echo "This container includes the following tools and languages:" >> "$claude_output"
    echo "" >> "$claude_output"
    
    # Base tools
    echo "### Base Tools" >> "$claude_output"
    echo "- Node.js 20.18.0" >> "$claude_output"
    echo "- npm (latest)" >> "$claude_output"
    echo "- Git" >> "$claude_output"
    echo "- GitHub CLI (gh)" >> "$claude_output"
    echo "- Claude Code (@anthropic-ai/claude-code)" >> "$claude_output"
    
    # Process selected items by category
    local last_category=""
    for i in "${!SELECTED_IDS[@]}"; do
        local category="${SELECTED_CATEGORIES[$i]}"
        local name="${SELECTED_NAMES[$i]}"
        
        # Get display name for category
        local category_display=""
        for j in "${!categories[@]}"; do
            if [[ "${categories[$j]}" == "$category" ]]; then
                category_display="${category_names[$j]}"
                break
            fi
        done
        
        if [[ "$category" != "$last_category" ]]; then
            echo "" >> "$claude_output"
            echo "### $category_display" >> "$claude_output"
            last_category="$category"
        fi
        
        echo "- $name" >> "$claude_output"
    done
    
    success "Generated CLAUDE.md with environment information"
}

# Function to create custom Dockerfile
create_custom_dockerfile() {
    mkdir -p "$TEMP_DIR"
    cp Dockerfile.base "$TEMP_DIR/Dockerfile"
    
    # Process selected components
    local installation_content=""
    
    for yaml_file in "${SELECTED_YAML_FILES[@]}"; do
        log "Processing: $yaml_file"
        local install_cmds=$(extract_installation_from_yaml "$yaml_file")
        if [[ -n "$install_cmds" ]]; then
            installation_content+="\n# From $yaml_file\n"
            installation_content+="$install_cmds\n"
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
    
    # Generate CLAUDE.md
    generate_claude_md
    
    # Insert CLAUDE.md copy instruction
    if [[ -f "$TEMP_DIR/CLAUDE.md" ]]; then
        log "CLAUDE.md generated successfully, adding to Dockerfile"
        sed -i.bak '/^# Set up volume mount points/i\
\
# Copy CLAUDE.md configuration to temp location (will be copied to workspace at runtime)\
COPY CLAUDE.md /tmp/CLAUDE.md\
RUN chmod 644 /tmp/CLAUDE.md\
' "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak"
    fi
    
    # Copy settings.local.json.template
    sed -i.bak '/^# Set up volume mount points/i\
\
# Copy settings.local.json template to temp location (will be copied to .claude at runtime)\
COPY settings.local.json.template /tmp/settings.local.json.template\
RUN chmod 644 /tmp/settings.local.json.template\
' "$TEMP_DIR/Dockerfile"
    rm -f "$TEMP_DIR/Dockerfile.bak"
}

# Check for host git configuration
check_host_git_config() {
    local config_dir="$HOME/.claude-code-k8s"
    
    if [[ -d "$config_dir" ]] && [[ -f "$config_dir/git-config/.gitconfig" ]]; then
        return 0
    fi
    return 1
}

# Create git configuration secret
create_git_config_secret() {
    local config_dir="$HOME/.claude-code-k8s"
    
    log "Creating Kubernetes secret for git configuration..."
    
    # Delete existing secret if it exists
    kubectl delete secret git-config -n ${NAMESPACE} --ignore-not-found=true
    
    # Create secret from files
    local secret_args="--from-file=gitconfig=$config_dir/git-config/.gitconfig"
    
    # Add optional files if they exist
    [[ -f "$config_dir/git-config/.git-credentials" ]] && \
        secret_args="$secret_args --from-file=git-credentials=$config_dir/git-config/.git-credentials"
    
    [[ -f "$config_dir/github/hosts.yml" ]] && \
        secret_args="$secret_args --from-file=gh-hosts=$config_dir/github/hosts.yml"
    
    # Create the secret
    kubectl create secret generic git-config -n ${NAMESPACE} $secret_args
    
    success "Git configuration secret created"
}

# Main execution
main() {
    log "=== Starting Container Component Configurator ==="
    
    check_deps
    
    [[ ! -d "$COMPONENTS_DIR" ]] && error "Components directory '$COMPONENTS_DIR' not found"
    
    # Check Colima status
    colima status &> /dev/null || error "Colima is not running\nPlease start Colima with: colima start --kubernetes"
    kubectl get nodes &> /dev/null || error "Kubernetes is not accessible\nPlease make sure Colima started with --kubernetes flag"
    
    success "Colima with Kubernetes is running and accessible"
    
    # Check for host git configuration
    USE_HOST_GIT_CONFIG=false
    if check_host_git_config; then
        info "Git configuration found in ~/.claude-code-k8s/"
        echo ""
        read -p "Use host git configuration in this deployment? [Y/n]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            USE_HOST_GIT_CONFIG=true
            success "Host git configuration will be included"
        else
            info "Host git configuration will not be used"
            echo "You can configure git later using setup-git.sh inside the container"
        fi
        echo ""
    fi
    
    # Check Nexus
    NEXUS_AVAILABLE=false
    if check_nexus; then
        NEXUS_AVAILABLE=true
        export DOCKER_BUILDKIT=0
        export NEXUS_BUILD_ARGS="--build-arg PIP_INDEX_URL=http://host.lima.internal:8081/repository/pypi-proxy/simple --build-arg PIP_TRUSTED_HOST=host.lima.internal --build-arg NPM_REGISTRY=http://host.lima.internal:8081/repository/npm-proxy/ --build-arg GOPROXY=http://host.lima.internal:8081/repository/go-proxy/ --build-arg USE_NEXUS_APT=true --build-arg NEXUS_APT_URL=http://host.lima.internal:8081"
        success "Nexus proxy will be used for package downloads"
    else
        log "Nexus not detected, using default package repositories"
    fi
    
    # Handle flags
    if [[ "$1" =~ ^(--clean|-c)$ ]]; then
        log "Cleaning up previous deployment..."
        kubectl delete deployment claude-code -n ${NAMESPACE} --ignore-not-found=true
        docker rmi ${IMAGE_NAME}:${IMAGE_TAG} 2>/dev/null || true
        rm -rf "$TEMP_DIR"
    fi
    
    # Component selection
    [[ ! "$1" =~ --no-select && ! "$2" =~ --no-select ]] && select_components
    
    # Build process
    log "Creating custom Dockerfile..."
    create_custom_dockerfile
    
    log "Building Docker image..."
    if [[ -f "$TEMP_DIR/CLAUDE.md" ]]; then
        cp entrypoint.sh "$TEMP_DIR/"
        cp setup-git.sh "$TEMP_DIR/"
        cp settings.local.json.template "$TEMP_DIR/"
        cd "$TEMP_DIR"
        log "Building from $TEMP_DIR with CLAUDE.md"
        if [[ -n "$NEXUS_BUILD_ARGS" ]]; then
            success "Using Nexus proxy for package downloads"
            docker build $NEXUS_BUILD_ARGS -t ${IMAGE_NAME}:${IMAGE_TAG} .
        else
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
        fi
        cd ..
    else
        if [[ -n "$NEXUS_BUILD_ARGS" ]]; then
            success "Using Nexus proxy for package downloads"
            docker build $NEXUS_BUILD_ARGS -t ${IMAGE_NAME}:${IMAGE_TAG} -f "$TEMP_DIR/Dockerfile" .
        else
            docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f "$TEMP_DIR/Dockerfile" .
        fi
    fi
    
    # Deploy
    log "Loading image into Colima..."
    docker save ${IMAGE_NAME}:${IMAGE_TAG} | colima ssh -- sudo ctr -n k8s.io images import -
    
    log "Applying Kubernetes resources..."
    kubectl apply -f kubernetes/namespace.yaml
    kubectl apply -f kubernetes/pvc.yaml
    
    # Create git config secret if using host configuration
    if [[ "$USE_HOST_GIT_CONFIG" = true ]]; then
        create_git_config_secret
    fi
    
    # Apply Nexus configuration if available
    if [[ "$NEXUS_AVAILABLE" = true ]]; then
        log "Applying Nexus proxy configuration..."
        kubectl apply -f kubernetes/nexus-config.yaml
    fi
    
    # Apply deployment
    kubectl apply -f kubernetes/deployment.yaml
    
    log "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/claude-code -n ${NAMESPACE}
    
    POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=claude-code -o jsonpath="{.items[0].metadata.name}")
    
    success "=== Deployment Complete ==="
    echo -e "Your AI Dev Environment is now running in container: ${YELLOW}${POD_NAME}${NC}"
    
    [[ "$NEXUS_AVAILABLE" = true ]] && success "✓ Container is configured to use Nexus proxy"
    
    info "\nFile Manager Access:"
    echo -e "A web-based file manager (Filebrowser) is included for easy file uploads/downloads."
    echo -e "To access it, run:"
    echo -e "${YELLOW}kubectl port-forward -n ${NAMESPACE} service/claude-code 8090:8090${NC}"
    echo -e "Then open: ${BLUE}http://localhost:8090${NC}"
    echo -e "Default credentials: ${YELLOW}admin / admin${NC} (change after first login!)"
    
    info "\nContainer Access:"
    echo -e "To connect to the container, run:"
    echo -e "${YELLOW}kubectl exec -it -n ${NAMESPACE} ${POD_NAME} -c claude-code -- su - claude${NC}"
    echo -e "\nOnce connected, you can start Claude Code with:"
    echo -e "${YELLOW}claude${NC}"
}

# Run main
main "$@"
