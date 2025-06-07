#!/bin/bash
set -e

# Configuration
IMAGE_NAME="claude-code"
IMAGE_TAG="latest"
NAMESPACE="claude-code"
TEMP_DIR=".build-temp"
LANGUAGES_CONFIG="languages.conf"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

# Function to display language selection menu with shopping cart interface
select_languages() {
    # Enable debugging for this function
    set +e  # Don't exit on error
    
    # Read available languages from config
    local languages=() display_names=() groups=() requires=() installations=() in_cart=()
    
    while IFS='|' read -r lang_id display_name group require installation; do
        [[ -z "$lang_id" || "$lang_id" =~ ^# ]] && continue
        languages+=("$lang_id")
        display_names+=("$display_name")
        groups+=("$group")
        requires+=("$require")
        installations+=("$installation")
        in_cart+=(false)
    done < "$LANGUAGES_CONFIG"
    
    local current=0 view="catalog" cart_cursor=0
    local total_items=${#languages[@]}
    local hint_message="" hint_timer=0
    
    # Terminal dimensions and pagination
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local catalog_width=$((term_width / 2 - 2))
    local cart_width=$((term_width / 2 - 2))
    local content_height=$((term_height - 8))  # Leave room for header/footer
    local catalog_page=0 cart_page=0
    local items_per_page=$((content_height - 2))  # Account for borders
    
    # Calculate total pages
    local total_pages=$(( (total_items + items_per_page - 1) / items_per_page ))
    
    # Hide cursor and disable echo
    tput civis
    stty -echo
    trap 'tput cnorm; stty echo' EXIT
    
    # Saved screen state for optimized rendering
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
                echo "${display_names[$j]}"
                return
            fi
        done
    }
    
    # Function to check if requirements are met
    requirements_met() {
        local item_requires=$1
        [[ -z "$item_requires" ]] && return 0
        
        IFS=',' read -ra REQS <<< "$item_requires"
        for req in "${REQS[@]}"; do
            has_group_in_cart "$req" || return 1
        done
        return 0
    }
    
    # Function to add/remove item from cart
    toggle_cart_item() {
        local index=$1
        local action=$2
        
        # Bounds checking
        if [[ $index -lt 0 ]] || [[ $index -ge ${#languages[@]} ]]; then
            return 1
        fi
        
        if [[ "$action" == "add" ]]; then
            # Check requirements
            if [[ -n "${requires[$index]}" ]] && ! requirements_met "${requires[$index]}"; then
                hint_message="⚠️  Requires: ${requires[$index]}"
                hint_timer=30
                return 1
            fi
            
            # Handle mutually exclusive groups
            if [[ "${groups[$index]}" == *"-version" ]]; then
                for j in "${!groups[@]}"; do
                    if [[ "${groups[$j]}" == "${groups[$index]}" ]] && [[ $j -ne $index ]] && [[ "${in_cart[$j]}" == true ]]; then
                        in_cart[$j]=false
                        hint_message="ℹ️  Replaced ${display_names[$j]} with ${display_names[$index]}"
                        hint_timer=30
                    fi
                done
            fi
            
            in_cart[$index]=true
            [[ -z "$hint_message" ]] && hint_message="✓ Added ${display_names[$index]} to cart" && hint_timer=20
        else
            in_cart[$index]=false
            
            # Check for dependent items
            local removed_group="${groups[$index]}"
            local dependents=""
            
            for j in "${!requires[@]}"; do
                # Skip if no requirements
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
                        dependents+="${display_names[$j]}"
                    fi
                fi
            done
            
            if [[ -n "$dependents" ]]; then
                hint_message="⚠️  Also removed dependent items: $dependents"
                hint_timer=40
            else
                hint_message="✓ Removed ${display_names[$index]} from cart"
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
            # Calculate centered position for bottom text
            local text_len=${#bottom_text}
            local center_pos=$(( (width - text_len - 4) / 2 ))
            
            # Draw left side of border
            for ((i=0; i<center_pos; i++)); do echo -ne "─"; done
            
            # Insert bottom text
            echo -ne " ${YELLOW}${bottom_text}${NC} "
            
            # Draw right side of border
            for ((i=0; i<width-center_pos-text_len-6; i++)); do echo -ne "─"; done
        else
            for ((i=0; i<width-2; i++)); do echo -ne "─"; done
        fi
        
        echo -ne "┘"
    }
    
    # Function to render catalog items for current page
    render_catalog() {
        local start_idx=$((catalog_page * items_per_page))
        local end_idx=$((start_idx + items_per_page))
        [[ $end_idx -gt $total_items ]] && end_idx=$total_items
        
        local display_row=3
        local last_group=""
        
        # Clear catalog area only once
        for ((row=3; row<content_height+3; row++)); do
            tput cup $row 2
            printf "%-$((catalog_width-4))s" " "
        done
        
        for ((idx=start_idx; idx<end_idx; idx++)); do
            [[ $display_row -ge $((content_height + 3)) ]] && break
            
            # Group headers
            if [[ "${groups[$idx]}" != "$last_group" ]]; then
                tput cup $display_row 2
                case "${groups[$idx]}" in
                    "python-version") printf "%b%s%b" "${GREEN}" "Python Versions" "${NC}" ;;
                    "python-tools") printf "%b%s%b" "${GREEN}" "Python Tools" "${NC}" ;;
                    "java-version") printf "%b%s%b" "${GREEN}" "Java Versions" "${NC}" ;;
                    "java-tools") printf "%b%s%b" "${GREEN}" "Java Build Tools" "${NC}" ;;
                    "scala-version") printf "%b%s%b" "${GREEN}" "Scala Versions" "${NC}" ;;
                    "rust-version") printf "%b%s%b" "${GREEN}" "Rust Versions" "${NC}" ;;
                    "go-version") printf "%b%s%b" "${GREEN}" "Go Versions" "${NC}" ;;
                    "ruby-version") printf "%b%s%b" "${GREEN}" "Ruby Versions" "${NC}" ;;
                    "dotnet-version") printf "%b%s%b" "${GREEN}" ".NET Versions" "${NC}" ;;
                    "php-version") printf "%b%s%b" "${GREEN}" "PHP Versions" "${NC}" ;;
                    "php-tools") printf "%b%s%b" "${GREEN}" "PHP Tools" "${NC}" ;;
                    "node-tools") printf "%b%s%b" "${GREEN}" "Node.js Tools" "${NC}" ;;
                    "standalone") printf "%b%s%b" "${GREEN}" "Other Languages" "${NC}" ;;
                esac
                last_group="${groups[$idx]}"
                ((display_row++))
            fi
            
            tput cup $display_row 2
            
            # Cursor
            [[ $view == "catalog" && $idx -eq $current ]] && printf "%b▸%b " "${BLUE}" "${NC}" || printf "  "
            
            # Check availability
            local available=true status=""
            
            if [[ "${in_cart[$idx]}" == true ]]; then
                printf "%b✓%b " "${GREEN}" "${NC}"
                status="${GREEN}(in cart)${NC}"
            elif [[ "${groups[$idx]}" == *"-version" ]] && has_group_in_cart "${groups[$idx]}"; then
                printf "%b○%b " "${RED}" "${NC}"
                available=false
                local existing=$(get_group_cart_item "${groups[$idx]}")
                status="${RED}($existing selected)${NC}"
            elif [[ -n "${requires[$idx]}" ]] && ! requirements_met "${requires[$idx]}"; then
                printf "%b○%b " "${YELLOW}" "${NC}"
                status="${YELLOW}(needs ${requires[$idx]})${NC}"
            else
                printf "○ "
            fi
            
            # Item name
            if [[ $available == true || "${in_cart[$idx]}" == true ]]; then
                printf "%s" "${display_names[$idx]}"
            else
                printf "%b%s%b" "${RED}" "${display_names[$idx]}" "${NC}"
            fi
            
            # Status
            if [[ -n "$status" ]]; then
                local name_len=${#display_names[$idx]}
                local padding=$((catalog_width - name_len - 8))
                [[ $padding -gt ${#status} ]] && tput cuf $((padding - ${#status})) && printf "%b" "$status"
            fi
            
            ((display_row++))
        done
        
        # Page indicator handling - only redraw if page count > 1
        if [[ $total_pages -gt 1 ]]; then
            # Redraw bottom border with centered page indicator
            local page_text="Page $((catalog_page + 1))/$total_pages"
            local text_len=${#page_text}
            local center_pos=$(( (catalog_width - text_len - 4) / 2 ))
            
            tput cup $((content_height + 3)) 0
            printf "└"
            
            # Draw left side of border
            for ((i=0; i<center_pos; i++)); do printf "─"; done
            
            # Insert page indicator
            printf " %b%s%b " "${YELLOW}" "${page_text}" "${NC}"
            
            # Draw right side of border (calculate exact remaining space)
            local remaining=$((catalog_width - center_pos - text_len - 4))
            for ((i=0; i<remaining; i++)); do printf "─"; done
            
            printf "┘"
        fi
    }
    
    # Function to render cart items
    render_cart() {
        local display_row=3
        local cart_items_array=()
        
        # Collect cart items
        for idx in "${!in_cart[@]}"; do
            [[ "${in_cart[$idx]}" == true ]] && cart_items_array+=($idx)
        done
        
        local cart_count=${#cart_items_array[@]}
        
        # Clear cart area only once
        for ((row=3; row<content_height+3; row++)); do
            tput cup $row $((catalog_width + 4))
            printf "%-$((cart_width-4))s" " "
        done
        
        tput cup $display_row $((catalog_width + 4))
        
        if [[ $cart_count -eq 0 ]]; then
            printf "%b%s%b" "${YELLOW}" "Cart is empty" "${NC}"
            ((display_row++))
            tput cup $display_row $((catalog_width + 4))
            printf "Add items with SPACE"
        else
            printf "%b%d items selected:%b" "${GREEN}" "$cart_count" "${NC}"
            ((display_row++))
            
            # Group cart items by type and display them
            local group_order=("python-version" "python-tools" "java-version" "java-tools" "scala-version" "rust-version" "go-version" "ruby-version" "dotnet-version" "php-version" "php-tools" "node-tools" "standalone")
            local cart_display_count=0
            
            for group_type in "${group_order[@]}"; do
                local group_has_items=false
                
                for idx in "${!in_cart[@]}"; do
                    if [[ "${in_cart[$idx]}" == true ]] && [[ "${groups[$idx]}" == "$group_type" ]]; then
                        # Only display group header once
                        if [[ $group_has_items == false ]]; then
                            ((display_row++))
                            if [[ $display_row -lt $((content_height + 3)) ]]; then
                                tput cup $display_row $((catalog_width + 4))
                                case "$group_type" in
                                    *-version) printf "%b━ %s ━%b" "${BLUE}" "${group_type%-version}" "${NC}" ;;
                                    *-tools) printf "%b━ %s tools ━%b" "${BLUE}" "${group_type%-tools}" "${NC}" ;;
                                    *) printf "%b━ other ━%b" "${BLUE}" "${NC}" ;;
                                esac
                                ((display_row++))
                                group_has_items=true
                            fi
                        fi
                        
                        # Display item if within view
                        if [[ $display_row -lt $((content_height + 3)) ]]; then
                            tput cup $display_row $((catalog_width + 4))
                            
                            # Cursor
                            [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]] && printf "%b▸%b " "${BLUE}" "${NC}" || printf "  "
                            
                            printf "• %s" "${display_names[$idx]}"
                            
                            # Remove hint
                            [[ $view == "cart" && $cart_display_count -eq $cart_cursor ]] && printf " %b[DEL to remove]%b" "${RED}" "${NC}"
                            
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
            info "═══ Claude Code Language Selection ═══"
            echo ""
            draw_box 0 2 $catalog_width $((content_height + 2)) "Available Languages"
            draw_box $((catalog_width + 2)) 2 $cart_width $((content_height + 2)) "Shopping Cart"
            
            # Instructions
            tput cup $((term_height - 2)) 0
            echo -e "${BLUE}─────────────────────────────────────────────────────────────────────────────${NC}"
            
            screen_initialized=true
        fi
        
        # Update pagination when cursor moves
        local current_page=$((current / items_per_page))
        if [[ $current_page != $catalog_page ]]; then
            catalog_page=$current_page
        fi
        
        # Only redraw what changed
        if [[ $last_catalog_page != $catalog_page || $last_view != $view || $last_current != $current || $force_catalog_update == true ]]; then
            render_catalog
            last_catalog_page=$catalog_page
            force_catalog_update=false
        fi
        
        if [[ $last_cart_page != $cart_page || $last_view != $view || $last_cart_cursor != $cart_cursor || $force_cart_update == true ]]; then
            render_cart
            last_cart_page=$cart_page
            force_cart_update=false
        fi
        
        # Update instructions if view changed
        if [[ $last_view != $view ]]; then
            tput cup $((term_height - 1)) 0
            tput el  # Clear line
            if [[ $view == "catalog" ]]; then
                echo -ne "${YELLOW}↑↓/jk:${NC} Navigate  ${YELLOW}←→/hl:${NC} Page  ${YELLOW}SPACE:${NC} Add to cart  ${YELLOW}TAB:${NC} Switch to cart  ${YELLOW}ENTER:${NC} Checkout  ${YELLOW}q:${NC} Cancel"
            else
                echo -ne "${YELLOW}↑↓/jk:${NC} Navigate  ${YELLOW}DEL/d:${NC} Remove  ${YELLOW}TAB:${NC} Switch to catalog  ${YELLOW}ENTER:${NC} Checkout  ${YELLOW}q:${NC} Cancel"
            fi
        fi
        
        # Display hint message
        if [[ $hint_timer -gt 0 ]]; then
            tput cup 1 0
            tput el
            local hint_pos=$(( (term_width - ${#hint_message}) / 2 ))
            tput cup 1 $hint_pos
            echo -ne "${YELLOW}$hint_message${NC}"
            ((hint_timer--))
        elif [[ $hint_timer -eq 0 && -n "$hint_message" ]]; then
            tput cup 1 0
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
                        ((current > 0)) && ((current--))
                    else
                        ((cart_cursor > 0)) && ((cart_cursor--))
                    fi
                    ;;
                "[B"|"OB") # Down arrow
                    if [[ $view == "catalog" ]]; then
                        ((current < total_items - 1)) && ((current++))
                    else
                        local cart_items_count=0
                        for ic in "${in_cart[@]}"; do [[ $ic == true ]] && ((cart_items_count++)); done
                        ((cart_cursor < cart_items_count - 1)) && ((cart_cursor++))
                    fi
                    ;;
                "[D"|"OD") # Left arrow (previous page)
                    if [[ $view == "catalog" && $catalog_page -gt 0 ]]; then
                        ((catalog_page--))
                        current=$((catalog_page * items_per_page))
                    fi
                    ;;
                "[C"|"OC") # Right arrow (next page)
                    if [[ $view == "catalog" && $catalog_page -lt $((total_pages - 1)) ]]; then
                        ((catalog_page++))
                        current=$((catalog_page * items_per_page))
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
                            # Force re-render
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
            # Bounds check
            if [[ $current -ge 0 ]] && [[ $current -lt ${#languages[@]} ]]; then
                if [[ "${in_cart[$current]}" == true ]]; then
                    toggle_cart_item $current "remove"
                else
                    toggle_cart_item $current "add"
                fi
                # Force re-render of both catalog and cart
                force_catalog_update=true
                force_cart_update=true
            fi
        elif [[ "$key" =~ ^[jJ]$ ]]; then
            if [[ $view == "catalog" ]]; then
                ((current < total_items - 1)) && ((current++))
            else
                local cart_items_count=0
                for ic in "${in_cart[@]}"; do [[ $ic == true ]] && ((cart_items_count++)); done
                ((cart_cursor < cart_items_count - 1)) && ((cart_cursor++))
            fi
        elif [[ "$key" =~ ^[kK]$ ]]; then
            if [[ $view == "catalog" ]]; then
                ((current > 0)) && ((current--))
            else
                ((cart_cursor > 0)) && ((cart_cursor--))
            fi
        elif [[ "$key" =~ ^[hH]$ && $view == "catalog" ]]; then
            if [[ $catalog_page -gt 0 ]]; then
                ((catalog_page--))
                current=$((catalog_page * items_per_page))
            fi
        elif [[ "$key" =~ ^[lL]$ && $view == "catalog" ]]; then
            if [[ $catalog_page -lt $((total_pages - 1)) ]]; then
                ((catalog_page++))
                current=$((catalog_page * items_per_page))
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
                # Force re-render
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
    SELECTED_INSTALLATIONS=""
    success "Building container with:"
    echo ""
    
    local any_selected=false
    local last_group=""
    
    for i in "${!languages[@]}"; do
        if [[ "${in_cart[$i]}" == true ]]; then
            [[ "${groups[$i]}" != "$last_group" ]] && echo "" && last_group="${groups[$i]}"
            echo -e "  ✓ ${display_names[$i]}"
            SELECTED_INSTALLATIONS+="\n${installations[$i]}\n"
            any_selected=true
        fi
    done
    
    [[ $any_selected == false ]] && echo -e "  No additional languages (base image only)"
    
    echo ""
    log "Ready to build with this configuration?"
    echo -n "Press ENTER to continue or 'q' to quit: "
    read -r CONFIRM
    
    [[ "$CONFIRM" =~ ^[qQ]$ ]] && log "Build cancelled." && exit 0
    
    # Re-enable exit on error
    set -e
}

# Function to create custom Dockerfile
create_custom_dockerfile() {
    mkdir -p "$TEMP_DIR"
    cp Dockerfile.base "$TEMP_DIR/Dockerfile"
    
    if [[ -n "$SELECTED_INSTALLATIONS" ]]; then
        echo -e "$SELECTED_INSTALLATIONS" > "$TEMP_DIR/installations.txt"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/r $TEMP_DIR/installations.txt" "$TEMP_DIR/Dockerfile"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak" "$TEMP_DIR/installations.txt"
    else
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak"
    fi
}

# No longer need this function - deployment.yaml handles both scenarios

# Main execution
main() {
    log "=== Building Claude Code Container for Kubernetes ==="
    
    check_deps
    
    [[ ! -f "$LANGUAGES_CONFIG" ]] && error "$LANGUAGES_CONFIG not found"
    
    # Check Colima status
    colima status &> /dev/null || error "Colima is not running\nPlease start Colima with: colima start --kubernetes"
    kubectl get nodes &> /dev/null || error "Kubernetes is not accessible\nPlease make sure Colima started with --kubernetes flag"
    
    success "Colima with Kubernetes is running and accessible"
    
    # Check Nexus
    NEXUS_AVAILABLE=false
    if check_nexus; then
        NEXUS_AVAILABLE=true
        export DOCKER_BUILDKIT=0
        export NEXUS_BUILD_ARGS="--build-arg PIP_INDEX_URL=http://host.lima.internal:8081/repository/pypi-proxy/simple/ --build-arg PIP_TRUSTED_HOST=host.lima.internal --build-arg NPM_REGISTRY=http://host.lima.internal:8081/repository/npm-proxy/ --build-arg GOPROXY=http://host.lima.internal:8081/repository/go-proxy/"
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
    
    # Language selection
    [[ ! "$1" =~ --no-select && ! "$2" =~ --no-select ]] && select_languages
    
    # Build process
    log "Creating custom Dockerfile..."
    create_custom_dockerfile
    
    log "Building Docker image..."
    if [[ -n "$NEXUS_BUILD_ARGS" ]]; then
        success "Using Nexus proxy for package downloads"
        docker build $NEXUS_BUILD_ARGS -t ${IMAGE_NAME}:${IMAGE_TAG} -f "$TEMP_DIR/Dockerfile" .
    else
        docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f "$TEMP_DIR/Dockerfile" .
    fi
    
    # Deploy
    log "Loading image into Colima..."
    docker save ${IMAGE_NAME}:${IMAGE_TAG} | colima ssh -- sudo ctr -n k8s.io images import -
    
    log "Applying Kubernetes resources..."
    kubectl apply -f kubernetes/namespace.yaml
    kubectl apply -f kubernetes/pvc.yaml
    
    # Apply Nexus configuration if available
    if [[ "$NEXUS_AVAILABLE" = true ]]; then
        log "Applying Nexus proxy configuration..."
        kubectl apply -f kubernetes/nexus-config.yaml
    fi
    
    # Apply the unified deployment
    kubectl apply -f kubernetes/deployment.yaml
    
    log "Waiting for deployment to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/claude-code -n ${NAMESPACE}
    
    POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=claude-code -o jsonpath="{.items[0].metadata.name}")
    
    success "=== Deployment Complete ==="
    echo -e "Claude Code is now running in container: ${YELLOW}${POD_NAME}${NC}"
    
    [[ "$NEXUS_AVAILABLE" = true ]] && success "✓ Container is configured to use Nexus proxy"
    
    info "\nFile Manager Access:"
    echo -e "A web-based file manager (Filebrowser) is included for easy file uploads/downloads."
    echo -e "To access it, run:"
    echo -e "${YELLOW}kubectl port-forward -n ${NAMESPACE} service/claude-code 8090:8090${NC}"
    echo -e "Then open: ${BLUE}http://localhost:8090${NC}"
    echo -e "Default credentials: ${YELLOW}admin / admin${NC} (change after first login!)"
    
    info "\nClaude Code Access:"
    echo -e "To connect to the container, run:"
    echo -e "${YELLOW}kubectl exec -it -n ${NAMESPACE} ${POD_NAME} -- su - claude${NC}"
    echo -e "\nOnce connected, you can start Claude Code with:"
    echo -e "${YELLOW}cd workspace${NC}"
    echo -e "${YELLOW}claude${NC}"
    
    log "\nCleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Run main
main "$@"
