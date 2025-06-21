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

# Clear and start
echo ""
echo ""

# ASCII Art with gradient colors
# Credit: "Big" font from https://www.asciiart.eu/text-to-ascii-art
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
echo -e "${DIM}                 Created by Eric Hausig${NC}"
echo -e "${DIM}               Powered by Ubuntu 22.04 LTS${NC}"
echo ""

# Check installed components
COMPONENTS=""

# Python (only if conda installed)
if command -v conda &> /dev/null 2>&1; then
    PYTHON_VERSION=$(python --version 2>&1 | grep -oP '\d+\.\d+' | head -1 || echo "")
    [ -n "$PYTHON_VERSION" ] && COMPONENTS="${COMPONENTS}  ${GREEN}● Python ${PYTHON_VERSION}${NC}"
fi

# Node.js
if command -v node &> /dev/null 2>&1; then
    NODE_VERSION=$(node --version | sed 's/v//' | grep -oP '\d+' | head -1 || echo "")
    [ -n "$NODE_VERSION" ] && COMPONENTS="${COMPONENTS}  ${YELLOW}● Node ${NODE_VERSION}${NC}"
fi

# Java
if command -v java &> /dev/null 2>&1; then
    JAVA_VERSION=$(java -version 2>&1 | head -1 | grep -oP '\d+' | head -1 || echo "")
    [ -n "$JAVA_VERSION" ] && COMPONENTS="${COMPONENTS}  ${RED}● Java ${JAVA_VERSION}${NC}"
fi

# Rust
if command -v rustc &> /dev/null 2>&1; then
    RUST_VERSION=$(rustc --version | grep -oP '\d+\.\d+' | head -1 || echo "")
    [ -n "$RUST_VERSION" ] && COMPONENTS="${COMPONENTS}  ${MAGENTA}● Rust ${RUST_VERSION}${NC}"
fi

# Go
if command -v go &> /dev/null 2>&1; then
    GO_VERSION=$(go version | grep -oP '\d+\.\d+' | head -1 || echo "")
    [ -n "$GO_VERSION" ] && COMPONENTS="${COMPONENTS}  ${CYAN}● Go ${GO_VERSION}${NC}"
fi

# Display components if any
#if [ -n "$COMPONENTS" ]; then
#    echo -e "   ${WHITE}Stack:${NC}${COMPONENTS}"
#    echo ""
#fi

# Claude Code special section
if command -v claude &> /dev/null 2>&1; then
    echo -e "   ${MAGENTA}╭───────────────────────────────────────────────────────────╮${NC}"
    echo -e "   ${MAGENTA}│${NC}   ${WHITE}Claude Code${NC} is ready! Type ${YELLOW}claude${NC} to start coding     ${MAGENTA}│${NC}"
    echo -e "   ${MAGENTA}╰───────────────────────────────────────────────────────────╯${NC}"
    echo ""
fi

# Quick status
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
if [ -z "$GIT_NAME" ]; then
    echo -e "   ${YELLOW}▸${NC} Run ${CYAN}setup-git.sh${NC} to configure Git"
else
    echo -e "   ${GREEN}✓${NC} Git: ${WHITE}${GIT_NAME}${NC}"
fi

# Memory status
if [ -f ~/.claude/CLAUDE.md ]; then
    IMPORT_COUNT=$(grep -c "@~/.claude/" ~/.claude/CLAUDE.md 2>/dev/null || echo "0")
    [ "$IMPORT_COUNT" -gt 0 ] && echo -e "   ${GREEN}✓${NC} Claude memory: ${IMPORT_COUNT} imports"
fi

# SSH info
if [ -n "$SSH_CONNECTION" ]; then
    SSH_FROM=$(echo $SSH_CONNECTION | awk '{print $1}')
    echo -e "   ${BLUE}◆${NC} SSH: ${WHITE}${SSH_FROM}${NC}"
    
    # Password check
    if [ -f /etc/shadow.backup ] && sudo grep -q "devuser" /etc/shadow.backup 2>/dev/null; then
        CURRENT_HASH=$(sudo grep "devuser" /etc/shadow 2>/dev/null | cut -d: -f2)
        BACKUP_HASH=$(sudo grep "devuser" /etc/shadow.backup 2>/dev/null | cut -d: -f2)
        if [ "$CURRENT_HASH" = "$BACKUP_HASH" ]; then
            echo -e "   ${YELLOW}⚠${NC}  Change password: ${CYAN}passwd${NC}"
        fi
    fi
fi

echo ""
echo -e "   ${DIM}Workspace: ${WHITE}~/workspace${NC}  ${DIM}•  File manager: ${WHITE}http://localhost:8090${NC}"
echo ""
echo ""
