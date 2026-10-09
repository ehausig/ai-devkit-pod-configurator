#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}AI DevKit Git Configuration Setup${NC}"
echo ""

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        echo -n "$prompt [$default]: "
    else
        echo -n "$prompt: "
    fi
    
    read -r response
    
    if [ -z "$response" ] && [ -n "$default" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$response'"
    fi
}

# Check if git is already configured
if git config --global user.name >/dev/null 2>&1 && git config --global user.email >/dev/null 2>&1; then
    echo -e "${YELLOW}Git is already configured:${NC}"
    echo "  Name:  $(git config --global user.name)"
    echo "  Email: $(git config --global user.email)"
    echo ""
    echo -n "Do you want to reconfigure? (y/N): "
    read -r reconfigure
    
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Keeping existing configuration.${NC}"
        exit 0
    fi
fi

# Get current values if they exist
current_name=$(git config --global user.name 2>/dev/null || echo "")
current_email=$(git config --global user.email 2>/dev/null || echo "")

# Prompt for configuration
echo ""
echo "Please provide your Git configuration:"
echo ""

prompt_with_default "Your name" "$current_name" git_name
prompt_with_default "Your email" "$current_email" git_email

# Configure git
echo ""
echo -e "${YELLOW}Configuring Git...${NC}"

git config --global user.name "$git_name"
git config --global user.email "$git_email"

# Set some sensible defaults
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "vim"

echo -e "${GREEN}✓ Git configured successfully!${NC}"
echo ""

# Show the configuration
echo -e "${BLUE}Current Git configuration:${NC}"
echo "  Name:  $(git config --global user.name)"
echo "  Email: $(git config --global user.email)"
echo "  Default branch: $(git config --global init.defaultBranch)"
echo "  Default editor: $(git config --global core.editor)"
echo ""

# Check if gh is available and test authentication
if command -v gh >/dev/null 2>&1; then
    echo -e "${BLUE}GitHub CLI Status:${NC}"
    if gh auth status >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} GitHub CLI is authenticated and ready"
        echo ""
        echo "You can now use gh commands like:"
        echo "  gh repo create, gh pr create, gh issue list, etc."
    else
        echo -e "  ${YELLOW}ℹ${NC} GitHub CLI will authenticate automatically when container starts"
        echo "  ${YELLOW}ℹ${NC} (using the GitHub token from git configuration)"
    fi
    echo ""
fi

echo -e "${GREEN}Git setup complete!${NC}"
echo ""
echo "You can always run this script again with:"
echo "  setup-git.sh"
echo ""
echo "Or manually configure git with:"
echo "  git config --global user.name \"Your Name\""
echo "  git config --global user.email \"your.email@example.com\""
echo ""

# Save configuration timestamp
mkdir -p ~/.config/ai-devkit
echo "Git configured on: $(date)" > ~/.config/ai-devkit/git-setup-timestamp

exit 0
