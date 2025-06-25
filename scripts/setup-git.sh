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

# Check if already configured
if git config --global user.name &> /dev/null && git config --global user.email &> /dev/null; then
    success "Git is already configured!"
    echo -e "  ${GREEN}✓${NC} User: $(git config --global user.name)"
    echo -e "  ${GREEN}✓${NC} Email: $(git config --global user.email)"
    echo ""
    read -p "Do you want to reconfigure? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Step 1: Configure git user
log "Step 1: Git User Configuration"
echo ""
read -p "Your name (for git commits): " git_name
read -p "Your email (for git commits): " git_email

git config --global user.name "$git_name"
git config --global user.email "$git_email"
git config --global init.defaultBranch main
git config --global pull.rebase false

success "Git user configured!"
echo ""

# Step 2: GitHub authentication
log "Step 2: GitHub Authentication Setup"
echo ""
echo "Claude Code requires GitHub authentication to:"
echo "  • Clone private repositories"
echo "  • Push changes to your repositories"
echo "  • Use GitHub CLI (gh) commands"
echo ""
echo "Choose authentication method:"
echo "  1. Personal Access Token (PAT) - Recommended"
echo "  2. Skip GitHub setup"
echo ""
read -p "Your choice (1-2): " auth_choice

case $auth_choice in
    1)
        echo ""
        info "Creating a Personal Access Token (PAT):"
        echo "1. Open: ${BLUE}https://github.com/settings/tokens/new${NC}"
        echo "2. Give it a descriptive name (e.g., 'AI DevKit Container')"
        echo "3. Select scopes:"
        echo "   ${GREEN}✓${NC} repo (Full control of private repositories)"
        echo "   ${GREEN}✓${NC} workflow (Update GitHub Action workflows)"
        echo "   ${GREEN}✓${NC} read:org (Read org and team membership)"
        echo "4. Set expiration (recommend 90 days for security)"
        echo "5. Click 'Generate token' and copy it"
        echo ""
        echo "Paste your token below (it will be hidden):"
        read -s github_pat
        echo ""
        
        if [[ -n "$github_pat" ]]; then
            # Configure git credentials
            git config --global credential.helper store
            
            # Test the token by getting user info
            github_user=$(curl -s -H "Authorization: token $github_pat" https://api.github.com/user | jq -r .login)
            
            if [[ "$github_user" != "null" ]] && [[ -n "$github_user" ]]; then
                # Store credentials
                echo "https://${github_user}:${github_pat}@github.com" > ~/.git-credentials
                chmod 600 ~/.git-credentials
                
                # Configure gh CLI
                mkdir -p ~/.config/gh
                cat > ~/.config/gh/hosts.yml << EOF
github.com:
    user: $github_user
    oauth_token: $github_pat
    git_protocol: https
EOF
                chmod 600 ~/.config/gh/hosts.yml
                
                success "GitHub authentication configured!"
                echo -e "  ${GREEN}✓${NC} Username: $github_user"
                echo -e "  ${GREEN}✓${NC} Git HTTPS authentication enabled"
                echo -e "  ${GREEN}✓${NC} GitHub CLI (gh) configured"
            else
                error "Invalid token or GitHub API error"
                rm -f ~/.git-credentials
            fi
        else
            info "Skipping GitHub authentication"
        fi
        ;;
    2)
        info "Skipping GitHub setup"
        ;;
    *)
        error "Invalid choice"
        exit 1
        ;;
esac

echo ""
success "Configuration complete!"
echo ""
echo "Your git configuration:"
git config --global --list | grep -E "user\.|credential\." | sed 's/^/  /'
echo ""

# Update prompt to show git branch
if ! grep -q "__git_ps1" ~/.bashrc; then
    log "Adding git branch to prompt..."
    cat >> ~/.bashrc << 'EOF'

# Git branch in prompt
parse_git_branch() {
    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
export PS1="\[\033[01;32m\]devuser@ai-devkit\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]\$(parse_git_branch)\[\033[00m\]$ "
EOF
    success "Git branch will now show in your prompt!"
    echo "Run 'source ~/.bashrc' to apply changes"
fi

echo ""
info "Next steps:"
echo "  • Clone a repo: git clone https://github.com/username/repo.git"
echo "  • Create a repo: gh repo create"
echo "  • Check auth: gh auth status"
