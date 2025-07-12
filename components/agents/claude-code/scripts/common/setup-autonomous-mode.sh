#!/bin/bash
# Setup script for Claude Code autonomous mode
# Usage: setup-autonomous-mode.sh [enable|disable|status]

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SETTINGS_FILE="$HOME/.claude/settings.json"
BASHRC_FILE="$HOME/.bashrc"

# Function to check current status
check_status() {
    local env_status="disabled"
    local bashrc_status="not found"
    local settings_status="not found"
    
    # Check environment variable
    if [ "$CLAUDE_AUTONOMOUS_MODE" = "true" ]; then
        env_status="enabled (current session)"
    fi
    
    # Check .bashrc
    if grep -q "CLAUDE_AUTONOMOUS_MODE=true" "$BASHRC_FILE" 2>/dev/null; then
        bashrc_status="enabled (persistent)"
    elif grep -q "CLAUDE_AUTONOMOUS_MODE" "$BASHRC_FILE" 2>/dev/null; then
        bashrc_status="configured but disabled"
    fi
    
    # Check settings.json
    if [ -f "$SETTINGS_FILE" ] && jq -e '.env.CLAUDE_AUTONOMOUS_MODE == "true"' "$SETTINGS_FILE" >/dev/null 2>&1; then
        settings_status="enabled"
    elif [ -f "$SETTINGS_FILE" ] && jq -e '.env | has("CLAUDE_AUTONOMOUS_MODE")' "$SETTINGS_FILE" >/dev/null 2>&1; then
        settings_status="configured but disabled"
    fi
    
    echo -e "${BLUE}=== Claude Code Autonomous Mode Status ===${NC}"
    echo ""
    echo -e "Environment Variable: ${env_status}"
    echo -e "Bashrc Configuration: ${bashrc_status}"
    echo -e "Settings.json: ${settings_status}"
    echo ""
    
    # Check if autonomous controller hook is installed
    if [ -f "$SETTINGS_FILE" ] && jq -e '.hooks.Stop[] | select(.hooks[].command == "cc-hook-autonomous-controller.sh")' "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Autonomous controller hook is installed${NC}"
    else
        echo -e "${RED}✗ Autonomous controller hook is NOT installed${NC}"
        echo -e "${YELLOW}  Run this script with 'enable' to install the hook${NC}"
    fi
    
    # Check if hook script exists
    if command -v cc-hook-autonomous-controller.sh >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Autonomous controller script is available${NC}"
    else
        echo -e "${RED}✗ Autonomous controller script is NOT available${NC}"
        echo -e "${YELLOW}  Ensure the Claude Code component is properly installed${NC}"
    fi
    
    echo ""
}

# Function to enable autonomous mode
enable_autonomous() {
    echo -e "${BLUE}=== Enabling Claude Code Autonomous Mode ===${NC}"
    echo ""
    
    # 1. Update .bashrc
    echo "Updating .bashrc..."
    if grep -q "CLAUDE_AUTONOMOUS_MODE" "$BASHRC_FILE" 2>/dev/null; then
        # Replace existing line
        sed -i 's/.*CLAUDE_AUTONOMOUS_MODE.*/export CLAUDE_AUTONOMOUS_MODE=true/' "$BASHRC_FILE"
        echo -e "${GREEN}✓ Updated existing configuration in .bashrc${NC}"
    else
        # Add new line
        echo "" >> "$BASHRC_FILE"
        echo "# Claude Code Autonomous Mode" >> "$BASHRC_FILE"
        echo "export CLAUDE_AUTONOMOUS_MODE=true" >> "$BASHRC_FILE"
        echo -e "${GREEN}✓ Added autonomous mode to .bashrc${NC}"
    fi
    
    # 2. Update settings.json
    echo "Updating Claude Code settings..."
    if [ ! -f "$SETTINGS_FILE" ]; then
        # Create basic settings file
        mkdir -p "$(dirname "$SETTINGS_FILE")"
        echo '{"env": {}}' > "$SETTINGS_FILE"
    fi
    
    # Update env.CLAUDE_AUTONOMOUS_MODE
    jq '.env.CLAUDE_AUTONOMOUS_MODE = "true"' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo -e "${GREEN}✓ Updated settings.json${NC}"
    
    # 3. Add autonomous controller hook if not present
    if ! jq -e '.hooks.Stop[] | select(.hooks[].command == "cc-hook-autonomous-controller.sh")' "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo "Adding autonomous controller hook..."
        
        # Ensure hooks structure exists
        jq '.hooks = (.hooks // {})' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        jq '.hooks.Stop = (.hooks.Stop // [])' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        
        # Add the autonomous controller hook as the first hook in Stop
        jq '.hooks.Stop = [{"matcher": "", "hooks": [{"type": "command", "command": "cc-hook-autonomous-controller.sh"}]}] + (.hooks.Stop | map(select(.hooks[].command != "cc-hook-autonomous-controller.sh")))' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        
        echo -e "${GREEN}✓ Added autonomous controller hook to settings${NC}"
    else
        echo -e "${GREEN}✓ Autonomous controller hook already configured${NC}"
    fi
    
    # 4. Set environment variable for current session
    export CLAUDE_AUTONOMOUS_MODE=true
    echo -e "${GREEN}✓ Enabled for current session${NC}"
    
    echo ""
    echo -e "${GREEN}🤖 Autonomous mode enabled successfully!${NC}"
    echo ""
    echo -e "${YELLOW}To use autonomous mode:${NC}"
    echo "1. Start a new terminal session (or run: source ~/.bashrc)"
    echo "2. Start Claude Code normally"
    echo "3. Initialize any persona - the system will run autonomously"
    echo ""
    echo -e "${YELLOW}Example:${NC}"
    echo '  > Please initialize the ARCHITECT persona and create a web app'
    echo '  (System will run through all personas automatically)'
    echo ""
}

# Function to disable autonomous mode
disable_autonomous() {
    echo -e "${BLUE}=== Disabling Claude Code Autonomous Mode ===${NC}"
    echo ""
    
    # 1. Update .bashrc
    echo "Updating .bashrc..."
    if grep -q "CLAUDE_AUTONOMOUS_MODE=true" "$BASHRC_FILE" 2>/dev/null; then
        sed -i 's/export CLAUDE_AUTONOMOUS_MODE=true/export CLAUDE_AUTONOMOUS_MODE=false/' "$BASHRC_FILE"
        echo -e "${GREEN}✓ Disabled in .bashrc${NC}"
    else
        echo -e "${YELLOW}✓ Not enabled in .bashrc${NC}"
    fi
    
    # 2. Update settings.json
    if [ -f "$SETTINGS_FILE" ]; then
        echo "Updating Claude Code settings..."
        jq '.env.CLAUDE_AUTONOMOUS_MODE = "false"' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
        echo -e "${GREEN}✓ Disabled in settings.json${NC}"
    fi
    
    # 3. Unset environment variable for current session
    export CLAUDE_AUTONOMOUS_MODE=false
    echo -e "${GREEN}✓ Disabled for current session${NC}"
    
    echo ""
    echo -e "${GREEN}✓ Autonomous mode disabled successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Claude Code will now operate in normal interactive mode.${NC}"
    echo ""
}

# Function to show usage
show_usage() {
    echo "Claude Code Autonomous Mode Setup"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  enable    - Enable autonomous mode"
    echo "  disable   - Disable autonomous mode"
    echo "  status    - Show current status"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 enable     # Enable autonomous mode"
    echo "  $0 status     # Check current configuration"
    echo "  $0 disable    # Disable autonomous mode"
    echo ""
    echo "What is Autonomous Mode?"
    echo "  When enabled, Claude Code will automatically:"
    echo "  • Execute work items without waiting for user input"
    echo "  • Transition between personas automatically"
    echo "  • Continue until all work is complete"
    echo "  • Handle handoffs between development phases"
    echo ""
    echo "This enables end-to-end autonomous development workflows."
}

# Main script logic
main() {
    case "${1:-status}" in
        "enable")
            enable_autonomous
            ;;
        "disable")
            disable_autonomous
            ;;
        "status")
            check_status
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    echo "Please install jq to use this script"
    exit 1
fi

# Run main function
main "$@"
