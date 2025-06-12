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
    local catalog_first_visible=0 catalog_last_visible=0
    local position_cursor_after_render=""
    
    # Terminal dimensions and pagination
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    local catalog_width=$((term_width / 2 - 2))
    local cart_width=$((term_width / 2 - 2))
    local content_height=$((term_height - 10))  # Adjusted for new header
    local catalog_page=0 cart_page=0
    
    # Calculate pagination properly by counting actual display rows
    # We need to figure out how many items fit per page accounting for group headers
    local page_boundaries=()  # Array to store the starting index of each page
    page_boundaries+=(0)  # First page starts at index 0
    
    local current_page_rows=0
    local last_display_group=""
    local page_start_idx=0
    
    for idx in "${!languages[@]}"; do
        # Determine the display group
        local display_group=""
        if [[ "${groups[$idx]}" == *"-version" ]]; then
            display_group="Languages"
        elif [[ "${groups[$idx]}" == "dev-tools" ]]; then
            display_group="Dev Tools"
        else
            display_group="${groups[$idx]}"
        fi
        
        # Count group header row if this is a new display group
        if [[ "$display_group" != "$last_display_group" ]]; then
            ((current_page_rows++))
            last_display_group="$display_group"
        fi
        
        # Count the item row
        ((current_page_rows++))
        
        # Check if we've exceeded the page height
        if [[ $current_page_rows -gt $((content_height - 2)) ]]; then
            # Start a new page at this index
            page_boundaries+=($idx)
            current_page_rows=1  # Reset counter (this item will be first on new page)
            
            # Also need to count its group header if it's different from previous
            if [[ $idx -gt 0 ]]; then
                local prev_display_group=""
                if [[ "${groups[$((idx-1))]}" == *"-version" ]]; then
                    prev_display_group="Languages"
                elif [[ "${groups[$((idx-1))]}" == "dev-tools" ]]; then
                    prev_display_group="Dev Tools"
                else
                    prev_display_group="${groups[$((idx-1))]}"
                fi
                
                if [[ "$display_group" != "$prev_display_group" ]]; then
                    ((current_page_rows++))
                fi
            fi
            last_display_group="$display_group"
        fi
    done
    
    local total_pages=${#page_boundaries[@]}
    local items_per_page=$((content_height - 2))  # This is approximate, actual items vary per page
    
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
            [[ -z "$hint_message" ]] && hint_message="✓ Added ${display_names[$index]} to stack" && hint_timer=20
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
        # Get the actual start and end indices for the current page
        local start_idx=${page_boundaries[$catalog_page]}
        local end_idx=$total_items
        
        # If there's a next page, end at the start of that page
        if [[ $((catalog_page + 1)) -lt ${#page_boundaries[@]} ]]; then
            end_idx=${page_boundaries[$((catalog_page + 1))]}
        fi
        
        local display_row=5
        local last_group=""
        local first_visible_idx=-1
        local last_visible_idx=-1
        
        # Clear catalog area completely with explicit character-by-character clearing
        for ((row=5; row<content_height+5; row++)); do
            tput cup $row 0
            # Print left border
            printf "│"
            # Clear the content area explicitly
            for ((col=1; col<catalog_width-1; col++)); do
                printf " "
            done
            # Print right border
            printf "│"
        done
        
        # Reset for actual rendering
        display_row=5
        last_group=""
        
        for ((idx=start_idx; idx<end_idx; idx++)); do
            [[ $display_row -ge $((content_height + 5)) ]] && break
            
            # Determine the display group (Languages or Dev Tools)
            local display_group=""
            if [[ "${groups[$idx]}" == *"-version" ]]; then
                display_group="Languages"
            elif [[ "${groups[$idx]}" == "dev-tools" ]]; then
                display_group="Dev Tools"
            else
                display_group="${groups[$idx]}"
            fi
            
            # Group headers - only show when display group changes
            if [[ "$display_group" != "$last_group" ]]; then
                tput cup $display_row 2
                printf "%b%s%b" "${GREEN}" "$display_group" "${NC}"
                last_group="$display_group"
                ((display_row++))
                [[ $display_row -ge $((content_height + 5)) ]] && break
            fi
            
            # Only render if we still have room
            if [[ $display_row -lt $((content_height + 5)) ]]; then
                # Track first and last visible items
                [[ $first_visible_idx -eq -1 ]] && first_visible_idx=$idx
                last_visible_idx=$idx
                
                tput cup $display_row 2
                
                # Cursor - using direct escape sequences to ensure proper rendering
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
                elif [[ -n "${requires[$idx]}" ]] && ! requirements_met "${requires[$idx]}"; then
                    printf "\033[1;33m○\033[0m "
                    status="(needs ${requires[$idx]})"
                    status_color="\033[1;33m"
                else
                    printf "○ "
                fi
                
                # Item name
                if [[ $available == true || "${in_cart[$idx]}" == true ]]; then
                    printf "%s" "${display_names[$idx]}"
                else
                    printf "\033[0;31m%s\033[0m" "${display_names[$idx]}"
                fi
                
                # Status
                if [[ -n "$status" ]]; then
                    local name_len=${#display_names[$idx]}
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
        
        # Store the visible range for navigation
        catalog_first_visible=$first_visible_idx
        catalog_last_visible=$last_visible_idx
        
        # Page indicator handling - only redraw if page count > 1
        if [[ $total_pages -gt 1 ]]; then
            # Redraw bottom border with centered page indicator
            local page_text="Page $((catalog_page + 1))/$total_pages"
            local text_len=${#page_text}
            local center_pos=$(( (catalog_width - text_len - 4) / 2 ))
            
            tput cup $((content_height + 5)) 0
            printf "└"
            
            # Draw left side of border
            for ((i=0; i<center_pos; i++)); do printf "─"; done
            
            # Insert page indicator
            printf " \033[1;33m%s\033[0m " "${page_text}"
            
            # Draw right side of border (calculate exact remaining space)
            local remaining=$((catalog_width - center_pos - text_len - 4))
            for ((i=0; i<remaining; i++)); do printf "─"; done
            
            printf "┘"
        else
            # Draw plain bottom border when only one page
            tput cup $((content_height + 3)) 0
            printf "└"
            for ((i=0; i<catalog_width-2; i++)); do printf "─"; done
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
        
        # Clear cart area only once
        for ((row=5; row<content_height+5; row++)); do
            tput cup $row $((catalog_width + 4))
            printf "%-$((cart_width-4))s" " "
        done
        
        tput cup $display_row $((catalog_width + 4))
        
        if [[ $cart_count -eq 0 ]]; then
            printf "%b%s%b" "${YELLOW}" "Build stack is empty" "${NC}"
            ((display_row++))
            tput cup $display_row $((catalog_width + 4))
            printf "Add items with SPACE"
        else
            printf "%b%d items selected:%b" "${GREEN}" "$cart_count" "${NC}"
            ((display_row++))
            
            # Dynamically build group order from the order they appear in languages.conf
            local group_order=()
            local seen_groups=()
            
            # Collect unique groups in the order they appear
            for idx in "${!groups[@]}"; do
                local group="${groups[$idx]}"
                local already_seen=false
                for seen in "${seen_groups[@]}"; do
                    if [[ "$seen" == "$group" ]]; then
                        already_seen=true
                        break
                    fi
                done
                if [[ $already_seen == false ]]; then
                    group_order+=("$group")
                    seen_groups+=("$group")
                fi
            done
            
            local cart_display_count=0
            
            for group_type in "${group_order[@]}"; do
                local group_has_items=false
                local current_display_group=""
                
                # First determine what the display group should be for this group_type
                if [[ "$group_type" == *"-version" ]]; then
                    current_display_group="Languages"
                elif [[ "$group_type" == "dev-tools" ]]; then
                    current_display_group="Dev Tools"
                else
                    current_display_group="$group_type"
                fi
                
                # Check if we should show a header for this display group
                local should_show_header=true
                for prev_type in "${group_order[@]}"; do
                    # Stop when we reach the current group
                    [[ "$prev_type" == "$group_type" ]] && break
                    
                    # Check if any previous group had the same display group
                    local prev_display_group=""
                    if [[ "$prev_type" == *"-version" ]]; then
                        prev_display_group="Languages"
                    elif [[ "$prev_type" == "dev-tools" ]]; then
                        prev_display_group="Dev Tools"
                    else
                        prev_display_group="$prev_type"
                    fi
                    
                    # If we've already shown this display group header, skip it
                    if [[ "$prev_display_group" == "$current_display_group" ]]; then
                        # Check if that previous group actually had items in cart
                        for idx in "${!in_cart[@]}"; do
                            if [[ "${in_cart[$idx]}" == true ]] && [[ "${groups[$idx]}" == "$prev_type" ]]; then
                                should_show_header=false
                                break
                            fi
                        done
                    fi
                done
                
                for idx in "${!in_cart[@]}"; do
                    if [[ "${in_cart[$idx]}" == true ]] && [[ "${groups[$idx]}" == "$group_type" ]]; then
                        # Only display group header once per display group
                        if [[ $group_has_items == false ]] && [[ $should_show_header == true ]]; then
                            ((display_row++))
                            if [[ $display_row -lt $((content_height + 5)) ]]; then
                                tput cup $display_row $((catalog_width + 4))
                                printf "%b━ %s ━%b" "${BLUE}" "$current_display_group" "${NC}"
                                ((display_row++))
                                group_has_items=true
                            fi
                        fi
                        
                        # Display item if within view
                        if [[ $display_row -lt $((content_height + 5)) ]]; then
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
    local is_rendering=false
    while true; do
        # Only clear screen on first draw
        if [[ $screen_initialized == false ]]; then
            clear
            
            # Center and style the title
            local title="Claude Code Dev Kit Builder"
            local title_len=${#title}
            local title_pos=$(( (term_width - title_len) / 2 ))
            
            # Draw a nice header with the title
            tput cup 0 0
            for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}━${NC}"; done
            
            tput cup 1 $title_pos
            echo -ne "${YELLOW}${title}${NC}"
            
            tput cup 2 0
            for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}━${NC}"; done
            
            echo ""  # Move to line 3
            draw_box 0 4 $catalog_width $((content_height + 2)) "Available Components"
            draw_box $((catalog_width + 2)) 4 $cart_width $((content_height + 2)) "Build Stack"
            
            # Instructions
            tput cup $((term_height - 2)) 0
            # Draw line across full terminal width
            for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}─${NC}"; done
            
            screen_initialized=true
        fi
        
        # Remove the old pagination update logic since we handle it in navigation now
        
        # Handle cursor positioning for page changes BEFORE checking if we need to render
        if [[ -n "$position_cursor_after_render" ]]; then
            # Need to render first to know visible items
            render_catalog
            
            if [[ "$position_cursor_after_render" == "first" ]]; then
                current=$catalog_first_visible
            elif [[ "$position_cursor_after_render" == "last" ]]; then
                current=$catalog_last_visible
            fi
            position_cursor_after_render=""
            
            # Now render again with the cursor in the right position
            render_catalog
            last_catalog_page=$catalog_page
            last_current=$current
        elif [[ $last_catalog_page != $catalog_page || $last_view != $view || $force_catalog_update == true ]]; then
            # Full render for page changes, view changes, or forced updates
            render_catalog
            last_catalog_page=$catalog_page
            force_catalog_update=false
        elif [[ $last_current != $current && $view == "catalog" ]]; then
            # Optimized cursor movement on same page
            if [[ $current -ge $catalog_first_visible && $current -le $catalog_last_visible && 
                  $last_current -ge $catalog_first_visible && $last_current -le $catalog_last_visible ]]; then
                # Both old and new positions are visible - just update the two affected rows
                
                # Function to calculate the actual screen row for an item index
                get_screen_row_for_item() {
                    local target_idx=$1
                    local row=5
                    local prev_display_group=""
                    
                    for ((idx=$catalog_first_visible; idx<=$catalog_last_visible && idx<=$target_idx; idx++)); do
                        # Determine the display group
                        local display_group=""
                        if [[ "${groups[$idx]}" == *"-version" ]]; then
                            display_group="Languages"
                        elif [[ "${groups[$idx]}" == "dev-tools" ]]; then
                            display_group="Dev Tools"
                        else
                            display_group="${groups[$idx]}"
                        fi
                        
                        # Add row for group header if this is a new display group
                        if [[ "$display_group" != "$prev_display_group" ]]; then
                            prev_display_group="$display_group"
                            ((row++))
                        fi
                        # If this is our target, return the row
                        if [[ $idx -eq $target_idx ]]; then
                            echo $row
                            return
                        fi
                        ((row++))
                    done
                }
                
                # Get the actual screen rows for old and new positions
                local old_screen_row=$(get_screen_row_for_item $last_current)
                local new_screen_row=$(get_screen_row_for_item $current)
                
                # Clear the old cursor position (just the cursor column)
                tput cup $old_screen_row 2
                printf "  "
                
                # Draw the new cursor
                tput cup $new_screen_row 2
                printf "\033[0;34m▸\033[0m "
            else
                # Cursor moved outside visible range - need full render
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
            tput el  # Clear line
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
        
        # Save state BEFORE processing input
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
                            # At first visible item, go to previous page
                            ((catalog_page--))
                            # Set a flag to position cursor after render
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
                            # At last visible item, go to next page
                            ((catalog_page++))
                            # Set a flag to position cursor after render
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
                "[D"|"OD") # Left arrow (previous page)
                    if [[ $view == "catalog" && $catalog_page -gt 0 ]]; then
                        ((catalog_page--))
                        position_cursor_after_render="first"
                    fi
                    ;;
                "[C"|"OC") # Right arrow (next page)
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
                if [[ $current -eq $catalog_last_visible ]] && [[ $catalog_page -lt $((total_pages - 1)) ]]; then
                    # At last visible item, go to next page
                    ((catalog_page++))
                    # Set a flag to position cursor after render
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
                    # At first visible item, go to previous page
                    ((catalog_page--))
                    # Set a flag to position cursor after render
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
    
    # Build final selections with consistent styling
    local term_width=$(tput cols)
    
    # Draw header
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
        
        # Group selections by type
        SELECTED_INSTALLATIONS=""
        SELECTED_LANGUAGES=()
        SELECTED_DISPLAY_NAMES=()
        SELECTED_GROUPS=()
        local last_display_group=""
        
        # Build groups in same order as main menu
        local group_order=()
        local seen_groups=()
        for idx in "${!groups[@]}"; do
            local group="${groups[$idx]}"
            local already_seen=false
            for seen in "${seen_groups[@]}"; do
                [[ "$seen" == "$group" ]] && already_seen=true && break
            done
            if [[ $already_seen == false ]]; then
                group_order+=("$group")
                seen_groups+=("$group")
            fi
        done
        
        # Display selected items grouped
        for group_type in "${group_order[@]}"; do
            local group_has_items=false
            local display_group=""
            
            # Determine display group
            if [[ "$group_type" == *"-version" ]]; then
                display_group="Languages"
            elif [[ "$group_type" == "dev-tools" ]]; then
                display_group="Dev Tools"
            else
                display_group="$group_type"
            fi
            
            # Check if we should show this group header
            if [[ "$display_group" != "$last_display_group" ]]; then
                # Check if this group has any selected items
                for i in "${!languages[@]}"; do
                    if [[ "${in_cart[$i]}" == true ]] && [[ "${groups[$i]}" == "$group_type" ]]; then
                        group_has_items=true
                        break
                    fi
                done
                
                if [[ $group_has_items == true ]]; then
                    [[ -n "$last_display_group" ]] && echo ""
                    echo -e "  ${BLUE}━ ${display_group} ━${NC}"
                    last_display_group="$display_group"
                fi
            fi
            
            # Display items in this group
            for i in "${!languages[@]}"; do
                if [[ "${in_cart[$i]}" == true ]] && [[ "${groups[$i]}" == "$group_type" ]]; then
                    echo -e "    ${GREEN}✓${NC} ${display_names[$i]}"
                    SELECTED_INSTALLATIONS+="\n${installations[$i]}\n"
                    # Store selections for CLAUDE.md generation
                    SELECTED_LANGUAGES+=("${languages[$i]}")
                    SELECTED_DISPLAY_NAMES+=("${display_names[$i]}")
                    SELECTED_GROUPS+=("${groups[$i]}")
                fi
            done
        done
    fi
    
    echo ""
    echo ""
    
    # Draw separator
    for ((i=0; i<term_width; i++)); do echo -ne "${BLUE}─${NC}"; done
    echo ""
    
    log "Ready to build with this configuration?"
    echo -ne "Press ${GREEN}ENTER${NC} to continue or ${RED}'q'${NC} to quit: "
    read -r CONFIRM
    
    [[ "$CONFIRM" =~ ^[qQ]$ ]] && log "Build cancelled." && exit 0
    
    # Re-enable exit on error
    set -e
}

# Global variables for selected items
declare -a SELECTED_LANGUAGES
declare -a SELECTED_DISPLAY_NAMES
declare -a SELECTED_GROUPS

# Function to generate CLAUDE.md from template and selections
generate_claude_md() {
    local claude_template="CLAUDE.md.template"
    local claude_output="$TEMP_DIR/CLAUDE.md"
    
    # Check if template exists
    if [[ ! -f "$claude_template" ]]; then
        log "Warning: $claude_template not found, skipping CLAUDE.md generation"
        return
    fi
    
    log "Generating CLAUDE.md from template..."
    
    # Copy template up to marker
    sed '/<!-- ENVIRONMENT_TOOLS_MARKER -->/q' "$claude_template" > "$claude_output"
    
    # Generate simple list of installed tools
    echo "" >> "$claude_output"
    echo "## Installed Development Environment" >> "$claude_output"
    echo "" >> "$claude_output"
    echo "This container includes the following tools and languages:" >> "$claude_output"
    echo "" >> "$claude_output"
    
    # Always include base tools that are installed by default
    echo "### Base Tools" >> "$claude_output"
    echo "- Node.js 20.18.0" >> "$claude_output"
    echo "- npm (latest)" >> "$claude_output"
    echo "- Git" >> "$claude_output"
    echo "- Python 3 (system)" >> "$claude_output"
    echo "- Claude Code (@anthropic-ai/claude-code)" >> "$claude_output"
    
    # Track which display groups we've shown
    local last_display_group="Base Tools"
    
    # Process selected items
    for i in "${!SELECTED_LANGUAGES[@]}"; do
        local display_name="${SELECTED_DISPLAY_NAMES[$i]}"
        local group="${SELECTED_GROUPS[$i]}"
        
        # Determine display group
        local display_group=""
        if [[ "$group" == *"-version" ]]; then
            display_group="Programming Languages"
        elif [[ "$group" == "dev-tools" ]]; then
            display_group="Development Tools"
        else
            display_group="Other Tools"
        fi
        
        # Show group header if it changed
        if [[ "$display_group" != "$last_display_group" ]]; then
            echo "" >> "$claude_output"
            echo "### $display_group" >> "$claude_output"
            last_display_group="$display_group"
        fi
        
        # Simply list the tool
        echo "- $display_name" >> "$claude_output"
    done
    
    log "CLAUDE.md content generated"
    log "Debug: CLAUDE.md exists at $claude_output: $([ -f "$claude_output" ] && echo "YES" || echo "NO")"
    log "Debug: CLAUDE.md size: $([ -f "$claude_output" ] && wc -c < "$claude_output" || echo "0") bytes"
    
    success "Generated CLAUDE.md with environment information"
}

# Function to create custom Dockerfile
create_custom_dockerfile() {
    mkdir -p "$TEMP_DIR"
    cp Dockerfile.base "$TEMP_DIR/Dockerfile"
    
    # First, handle language installations
    if [[ -n "$SELECTED_INSTALLATIONS" ]]; then
        echo -e "$SELECTED_INSTALLATIONS" > "$TEMP_DIR/installations.txt"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/r $TEMP_DIR/installations.txt" "$TEMP_DIR/Dockerfile"
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak" "$TEMP_DIR/installations.txt"
    else
        sed -i.bak "/# LANGUAGE_INSTALLATIONS_PLACEHOLDER/d" "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak"
    fi
    
    # Generate CLAUDE.md
    if [[ ${#SELECTED_LANGUAGES[@]} -gt 0 ]]; then
        generate_claude_md
    else
        log "No selections made, generating CLAUDE.md for base image"
        # Initialize empty arrays so generate_claude_md works correctly
        SELECTED_LANGUAGES=()
        SELECTED_DISPLAY_NAMES=()
        SELECTED_GROUPS=()
        generate_claude_md
    fi
    
    # Insert CLAUDE.md copy instruction BEFORE the VOLUME instruction
    if [[ -f "$TEMP_DIR/CLAUDE.md" ]]; then
        log "CLAUDE.md generated successfully, adding to Dockerfile"
        # Find the line with VOLUME and insert before it
        sed -i.bak '/^# Set up volume mount points/i\
\
# Copy CLAUDE.md configuration to temp location (will be copied to workspace at runtime)\
COPY CLAUDE.md /tmp/CLAUDE.md\
RUN chmod 644 /tmp/CLAUDE.md\
' "$TEMP_DIR/Dockerfile"
        rm -f "$TEMP_DIR/Dockerfile.bak"
    else
        log "Warning: CLAUDE.md was not generated"
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
    
    # Language selection
    [[ ! "$1" =~ --no-select && ! "$2" =~ --no-select ]] && select_languages
    
    # Build process
    log "Creating custom Dockerfile..."
    create_custom_dockerfile
    
    log "Building Docker image..."
    # Ensure CLAUDE.md and entrypoint.sh are in the build context
    if [[ -f "$TEMP_DIR/CLAUDE.md" ]]; then
        # Copy the current entrypoint.sh to ensure we have the latest version
        cp entrypoint.sh "$TEMP_DIR/"
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
        # Fallback to original build method
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
    # Temporarily disable cleanup for debugging
    # rm -rf "$TEMP_DIR"
    log "Debug: Temporary files preserved in $TEMP_DIR"
}

# Run main
main "$@"
