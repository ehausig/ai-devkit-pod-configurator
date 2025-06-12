#!/bin/bash
# Git and GitHub setup script for Claude Code container

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
if [[ -z "$CURRENT_NAME" ]]; then
    read -p "Enter your name for git commits: " GIT_NAME
    git config --global user.name "$GIT_NAME"
    success "Git user name configured"
fi

if [[ -z "$CURRENT_EMAIL" ]]; then
    read -p "Enter your email for git commits: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
    success "Git email configured"
fi

# Configure additional git settings
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor vim

success "Git configuration complete"

# GitHub CLI authentication
echo ""
log "GitHub CLI Authentication"
echo ""

# Check if already authenticated
if gh auth status &>/dev/null; then
    success "Already authenticated with GitHub"
    gh auth status
    
    # Check if git is configured to use gh
    if ! git config --global credential.helper | grep -q "gh auth git-credential" 2>/dev/null; then
        echo ""
        log "Git is not configured to use GitHub CLI credentials"
        read -p "Configure git to use GitHub CLI for authentication? (Y/n): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            gh auth setup-git
            success "Git configured to use GitHub CLI credentials"
        fi
    fi
else
    info "You need to authenticate with GitHub to use gh CLI"
    echo ""
    echo "Authentication options:"
    echo "1) Login with web browser (recommended)"
    echo "2) Login with authentication token"
    echo "3) Skip GitHub authentication"
    echo ""
    read -p "Choose an option (1-3): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            log "Starting GitHub authentication via web browser..."
            echo ""
            info "You'll be prompted to:"
            echo "  1. Press Enter to open github.com in your browser"
            echo "  2. Login and authorize GitHub CLI"
            echo "  3. Copy the one-time code shown and enter it here"
            echo ""
            gh auth login --web --git-protocol https
            
            if gh auth status &>/dev/null; then
                success "GitHub CLI authenticated"
                echo ""
                log "Configuring git to use GitHub CLI for authentication..."
                gh auth setup-git
                success "Git configured to use GitHub CLI credentials"
            fi
            ;;
        2)
            log "Starting GitHub authentication via token..."
            echo ""
            info "You'll need a GitHub Personal Access Token with:"
            echo "  • repo (full control of private repositories)"
            echo "  • workflow (optional, for GitHub Actions)"
            echo "  • read:org (optional, for organization access)"
            echo ""
            echo "Create a token at: https://github.com/settings/tokens/new"
            echo ""
            gh auth login --with-token --git-protocol https
            
            if gh auth status &>/dev/null; then
                success "GitHub CLI authenticated"
                echo ""
                log "Configuring git to use GitHub CLI for authentication..."
                gh auth setup-git
                success "Git configured to use GitHub CLI credentials"
            fi
            ;;
        3)
            info "Skipping GitHub authentication"
            echo "You can run 'setup-git.sh' again later to authenticate"
            ;;
        *)
            error "Invalid option"
            ;;
    esac
fi

# Set up SSH keys if needed
echo ""
log "SSH Key Configuration"
echo ""

if [[ -f ~/.ssh/id_ed25519 ]] || [[ -f ~/.ssh/id_rsa ]]; then
    success "SSH keys already exist"
else
    read -p "Generate SSH key for git operations? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
        success "SSH key generated"
        echo ""
        info "Your public SSH key:"
        echo ""
        cat ~/.ssh/id_ed25519.pub
        echo ""
        
        if gh auth status &>/dev/null; then
            read -p "Add this SSH key to your GitHub account? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                read -p "Enter a title for this SSH key (e.g., 'Claude Code Container'): " KEY_TITLE
                gh ssh-key add ~/.ssh/id_ed25519.pub --title "$KEY_TITLE"
                success "SSH key added to GitHub"
            fi
        else
            info "To add this key to GitHub manually:"
            echo "  1. Copy the key above"
            echo "  2. Go to https://github.com/settings/keys"
            echo "  3. Click 'New SSH key' and paste the key"
        fi
    fi
fi

# Final summary
echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo ""
info "Git configuration:"
git config --global --list | grep -E "user\.|core\.|init\." | sed 's/^/  /'
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
echo "  • gh repo clone <owner>/<repo>"
echo "  • claude"
echo ""

# Add troubleshooting section
info "Troubleshooting:"
echo "  • If 'git push' fails, run: gh auth setup-git"
echo "  • For SSH instead of HTTPS: gh config set git_protocol ssh"
echo "  • Check auth status: gh auth status"
echo "  • View git config: git config --global --list | grep credential"
echo ""
