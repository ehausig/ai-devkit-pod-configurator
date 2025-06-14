#!/bin/bash
# Git and GitHub setup script for Claude Code container
# This script configures git within the container using HTTPS authentication

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log() { echo -e "${YELLOW}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

echo -e "${BLUE}=== Git & GitHub Configuration Setup ===${NC}\n"

# Check if git config already exists
CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [[ -n "$CURRENT_NAME" && -n "$CURRENT_EMAIL" ]]; then
    info "Current git configuration:"
    echo "  Name:  $CURRENT_NAME"
    echo "  Email: $CURRENT_EMAIL"
    echo ""
    read -p "Do you want to update these settings? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Keeping existing git configuration"
    else
        CURRENT_NAME=""
        CURRENT_EMAIL=""
    fi
fi

# Configure git user
if [[ -z "$CURRENT_NAME" || -z "$CURRENT_EMAIL" ]]; then
    log "Configuring Git User Information"
    echo ""
    
    if [[ -z "$CURRENT_NAME" ]]; then
        read -p "Enter your name for git commits: " GIT_NAME
        [[ -z "$GIT_NAME" ]] && error "Git user name is required"
        git config --global user.name "$GIT_NAME"
        success "Git user name configured"
    fi
    
    if [[ -z "$CURRENT_EMAIL" ]]; then
        read -p "Enter your email for git commits: " GIT_EMAIL
        [[ -z "$GIT_EMAIL" ]] && error "Git email is required"
        git config --global user.email "$GIT_EMAIL"
        success "Git email configured"
    fi
fi

# Configure additional git settings
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor vim
git config --global credential.helper store

# Force HTTPS for GitHub
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://".insteadOf git://

success "Git configuration complete"

# GitHub CLI authentication
echo ""
log "GitHub Authentication Setup"
echo ""

# Check if already authenticated
if gh auth status &>/dev/null; then
    success "Already authenticated with GitHub"
    gh auth status
    echo ""
    read -p "Do you want to reconfigure GitHub authentication? (y/N): " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

info "Choose your authentication method:"
echo ""
echo "GitHub authentication options:"
echo "1) Personal Access Token (PAT) - Recommended for automation"
echo "2) OAuth via web browser - Interactive login"
echo "3) Skip GitHub authentication"
echo ""
read -p "Choose an option (1-3): " -n 1 -r
echo ""

case $REPLY in
    1)
        log "Setting up GitHub Personal Access Token..."
        echo ""
        info "You'll need a GitHub Personal Access Token with:"
        echo -e "  ${GREEN}✓${NC} repo (Full control of private repositories)"
        echo -e "  ${GREEN}✓${NC} workflow (Update GitHub Action workflows)"
        echo -e "  ${GREEN}✓${NC} read:org (Read org and team membership)"
        echo ""
        echo -e "Create a token at: ${BLUE}https://github.com/settings/tokens/new${NC}"
        echo ""
        
        # Use gh auth login with token
        gh auth login --with-token
        
        if gh auth status &>/dev/null; then
            success "GitHub CLI authenticated with PAT"
            echo ""
            log "Configuring git to use GitHub CLI for authentication..."
            gh auth setup-git
            success "Git configured to use GitHub CLI credentials"
        else
            error "GitHub authentication failed"
        fi
        ;;
        
    2)
        log "Starting GitHub authentication via web browser..."
        echo ""
        info "You'll be prompted to:"
        echo "  1. Press Enter to open github.com in your browser"
        echo "  2. Enter the one-time code shown here"
        echo "  3. Login and authorize GitHub CLI"
        echo ""
        
        # Use web authentication
        gh auth login --web
        
        if gh auth status &>/dev/null; then
            success "GitHub CLI authenticated via OAuth"
            echo ""
            log "Configuring git to use GitHub CLI for authentication..."
            gh auth setup-git
            success "Git configured to use GitHub CLI credentials"
            
            # Ensure HTTPS is used for git operations
            gh config set git_protocol https
            success "GitHub CLI configured to use HTTPS"
        else
            error "GitHub authentication failed"
        fi
        ;;
        
    3)
        info "Skipping GitHub authentication"
        echo "You can run this script again later to authenticate"
        ;;
        
    *)
        error "Invalid option"
        ;;
esac

# Final summary
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
info "Git configuration:"
git config --global --list | grep -E "user\.|url\.|credential\." | sed 's/^/  /'
echo ""

if gh auth status &>/dev/null; then
    info "GitHub CLI status:"
    gh auth status 2>&1 | sed 's/^/  /'
else
    info "GitHub CLI: Not authenticated"
fi

echo ""
info "Next steps:"
echo "  • cd ~/workspace"
echo "  • gh repo clone <owner>/<repo> (if authenticated)"
echo "  • git clone https://github.com/<owner>/<repo>.git"
echo "  • claude"
echo ""

# Add troubleshooting section
info "Troubleshooting:"
echo "  • If 'git push' fails, run: gh auth setup-git"
echo "  • Check auth status: gh auth status"
echo "  • View git config: git config --global --list"
echo "  • Your git credentials are stored in ~/.git-credentials"
echo ""
