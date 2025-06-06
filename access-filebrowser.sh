#!/bin/bash
# Convenience script to access Claude Code's Filebrowser

set -e

# Configuration
NAMESPACE="claude-code"
SERVICE_NAME="claude-code"
LOCAL_PORT="${FILEBROWSER_PORT:-8090}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Claude Code Filebrowser Access ===${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if deployment exists
if ! kubectl get deployment claude-code -n ${NAMESPACE} &> /dev/null; then
    echo -e "${RED}Error: Claude Code deployment not found${NC}"
    echo -e "Please deploy Claude Code first using ./build-and-deploy.sh"
    exit 1
fi

# Check if port is already in use
if lsof -i :${LOCAL_PORT} &> /dev/null; then
    echo -e "${YELLOW}Port ${LOCAL_PORT} is already in use${NC}"
    echo -e "Filebrowser may already be accessible at: ${BLUE}http://localhost:${LOCAL_PORT}${NC}"
    echo -n "Kill existing process and restart? (y/N): "
    read -r RESTART
    
    if [[ "$RESTART" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping existing process...${NC}"
        lsof -ti :${LOCAL_PORT} | xargs kill -9 2>/dev/null || true
        sleep 2
    else
        exit 0
    fi
fi

# Start port forwarding
echo -e "${YELLOW}Starting port forwarding...${NC}"
echo -e "${GREEN}Filebrowser will be available at: ${BLUE}http://localhost:${LOCAL_PORT}${NC}"
echo -e "\nDefault credentials:"
echo -e "  Username: ${YELLOW}admin${NC}"
echo -e "  Password: ${YELLOW}admin${NC}"
echo -e "\n${YELLOW}Press Ctrl+C to stop${NC}\n"

# Open browser if available
if command -v xdg-open &> /dev/null; then
    sleep 2 && xdg-open "http://localhost:${LOCAL_PORT}" &
elif command -v open &> /dev/null; then
    sleep 2 && open "http://localhost:${LOCAL_PORT}" &
fi

# Start port forwarding in foreground
kubectl port-forward -n ${NAMESPACE} service/${SERVICE_NAME} ${LOCAL_PORT}:8090
