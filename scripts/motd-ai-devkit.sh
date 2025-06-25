#!/bin/bash

# Colors
CYAN='\033[0;96m'
BLUE='\033[0;94m'
GREEN='\033[0;92m'
YELLOW='\033[0;93m'
MAGENTA='\033[0;95m'
RED='\033[0;91m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DIM='\033[2m'
NC='\033[0m'
BOLD='\033[1m'

# Get version if available
VERSION_FILE="/etc/ai-devkit-version"
if [[ -f "$VERSION_FILE" ]]; then
    VERSION=$(cat "$VERSION_FILE")
    VERSION_TEXT="Version ${VERSION}"
else
    VERSION_TEXT="Development Build"
fi

# Clear and start
echo ""
echo ""

# ASCII Art with gradient colors
echo -e "${CYAN}              _____   _____             _  ___ _   ${NC}"
echo -e "${CYAN}        /\\   |_   _| |  __ \\           | |/ (_) |  ${NC}"
echo -e "${BLUE}       /  \\    | |   | |  | | _____   _| ' / _| |_ ${NC}"
echo -e "${BLUE}      / /\\ \\   | |   | |  | |/ _ \\ \\ / /  < | | __|${NC}"
echo -e "${MAGENTA}     / ____ \\ _| |_  | |__| |  __/\\ V /| . \\| | |_ ${NC}"
echo -e "${MAGENTA}    /_/    \\_\\_____| |_____/ \\___| \\_/ |_|\\_\\_|\\__|${NC}"
echo ""
echo -e "${WHITE}     A R T I F I C I A L   I N T E L L I G E N C E${NC}"
echo -e "${GRAY}              D E V E L O P M E N T   K I T${NC}"
echo ""
echo -e "${YELLOW}                    ${VERSION_TEXT}${NC}"
echo ""
echo -e "${DIM}                 Created by Eric Hausig${NC}"
echo -e "${DIM}               Powered by Ubuntu 22.04 LTS${NC}"
echo ""
echo ""
