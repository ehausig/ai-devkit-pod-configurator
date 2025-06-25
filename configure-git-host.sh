#!/bin/bash
# Host-based Git configuration script for AI DevKit
# This script creates an isolated git configuration for containers
# using HTTPS and Personal Access Tokens (PAT)

set -e

# Configuration
CONFIG_DIR="$HOME/.ai-devkit"
GIT_CONFIG_DIR="$CONFIG_DIR/git-config"
GITHUB_CONFIG_DIR="$CONFIG_DIR/github"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log() { echo -e "${YELLOW}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Print banner
print_banner() {
    echo -e "${BLUE}=== AI DevKit - Git Configuration Manager ===${NC}"
    echo ""
    info "This tool creates an isolated git configuration for your containers"
    info "using HTTPS authentication with GitHub Personal Access Tokens"
    echo ""
}

# Check if configuration exists
check_existing_config() {
    if [[ -d "$CONFIG_DIR" ]] && [[ -f "$GIT_CONFIG_DIR/.gitconfig" ]]; then
        return 0
    fi
    return 1
}

# Create directory structure
create_directories() {
    mkdir -p "$GIT_CONFIG_DIR"
    mkdir -p "$GITHUB_CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"
    chmod 700 "$GIT_CONFIG_DIR"
    chmod 700 "$GITHUB_CONFIG_DIR"
}

# Configure git user
configure_git_user() {
    log "Step 1: Git User Configuration"
    echo ""
    info "This information will be used for git commits in your containers"
    echo ""
    
    # Prompt for git user info
    read -p "Your name (for git commits): " git_name
    [[ -z "$git_name" ]] && error "Git user name is required"
    
    read -p "Your email (for git commits): " git_email
    [[ -z "$git_email" ]] && error "Git email is required"
    
    # Create isolated .gitconfig
    cat > "$GIT_CONFIG_DIR/.gitconfig" << EOF
[user]
    name = $git_name
    email = $git_email
[init]
    defaultBranch = main
[pull]
    rebase = false
[core]
    editor = vim
[credential]
    helper = store
[url "https://github.com/"]
    insteadOf = git@github.com:
[url "https://"]
    insteadOf = git://
EOF
    
    chmod 600 "$GIT_CONFIG_DIR/.gitconfig"
    success "Git configuration created"
    echo ""
}

# Configure GitHub PAT
configure_github_pat() {
    log "Step 2: GitHub Authentication Setup"
    echo ""
    info "AI agents need a GitHub Personal Access Token (PAT) to:"
    echo "  • Clone private repositories"
    echo "  • Push changes to your repositories"
    echo "  • Use GitHub CLI (gh) commands"
    echo ""
    echo "Required permissions for your PAT:"
    echo -e "  ${GREEN}✓${NC} repo (Full control of private repositories)"
    echo -e "  ${GREEN}✓${NC} workflow (Update GitHub Action workflows)"
    echo -e "  ${GREEN}✓${NC} read:org (Read org and team membership)"
    echo ""
    echo "To create a token:"
    echo -e "  1. Open: ${BLUE}https://github.com/settings/tokens/new${NC}"
    echo "  2. Give it a descriptive name (e.g., 'AI DevKit')"
    echo "  3. Select the permissions listed above"
    echo "  4. Set expiration (recommend 90 days for security)"
    echo "  5. Click 'Generate token' and copy it"
    echo ""
    
    # Read PAT securely
    echo "Paste your token below (it will be hidden for security):"
    read -s -p "GitHub Personal Access Token: " github_pat
    echo ""
    [[ -z "$github_pat" ]] && error "GitHub PAT is required"
    
    # Test the PAT
    echo ""
    log "Validating GitHub credentials..."
    
    # Make API call to verify token and get user info
    local api_response=$(curl -s -H "Authorization: token $github_pat" https://api.github.com/user)
    
    if echo "$api_response" | grep -q "\"login\""; then
        # Extract username using sed (macOS compatible)
        local github_username=$(echo "$api_response" | sed -n 's/.*"login"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        local user_name=$(echo "$api_response" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        
        success "GitHub authentication verified!"
        echo -e "  ${GREEN}✓${NC} Username: $github_username"
        [[ -n "$user_name" ]] && echo -e "  ${GREEN}✓${NC} Full name: $user_name"
        
        # Store credentials in git-credentials format
        echo "https://${github_username}:${github_pat}@github.com" > "$GIT_CONFIG_DIR/.git-credentials"
        chmod 600 "$GIT_CONFIG_DIR/.git-credentials"
        
        # Create hosts.yml for gh CLI compatibility
        cat > "$GITHUB_CONFIG_DIR/hosts.yml" << EOF
github.com:
    user: $github_username
    oauth_token: $github_pat
    git_protocol: https
EOF
        chmod 600 "$GITHUB_CONFIG_DIR/hosts.yml"
        
        success "GitHub credentials saved securely"
        echo ""
    else
        # Check for specific error messages
        if echo "$api_response" | grep -q "Bad credentials"; then
            error "Invalid token. Please check your PAT and try again."
        elif echo "$api_response" | grep -q "401"; then
            error "Authentication failed. Token may be expired or revoked."
        else
            error "Failed to validate GitHub credentials. Please check your token and network connection."
        fi
    fi
}

# Show configuration summary
show_summary() {
    echo ""
    echo -e "${GREEN}=== Configuration Complete! ===${NC}"
    echo ""
    
    if [[ -f "$GIT_CONFIG_DIR/.gitconfig" ]]; then
        info "Git user configuration:"
        grep -E "name|email" "$GIT_CONFIG_DIR/.gitconfig" | sed 's/^/  /'
        echo ""
    fi
    
    if [[ -f "$GIT_CONFIG_DIR/.git-credentials" ]]; then
        # Extract username using sed (macOS compatible)
        local github_user=$(sed -n 's|https://\([^:]*\):.*@github.com|\1|p' "$GIT_CONFIG_DIR/.git-credentials" 2>/dev/null || echo "unknown")
        info "GitHub authentication:"
        echo "  • User: $github_user"
        echo "  • Auth: Personal Access Token (HTTPS)"
        echo ""
    fi
    
    info "Configuration location:"
    echo "  $CONFIG_DIR/"
    echo ""
    
    success "Your containers will now have:"
    echo -e "  ${GREEN}✓${NC} Git configured with your identity"
    echo -e "  ${GREEN}✓${NC} GitHub authentication via HTTPS"
    echo -e "  ${GREEN}✓${NC} GitHub CLI (gh) ready to use"
    echo -e "  ${GREEN}✓${NC} Ability to clone, push, and pull from private repos"
    echo ""
    
    info "Next steps:"
    echo -e "  1. Run ${YELLOW}./build-and-deploy.sh${NC}"
    echo "  2. When prompted, choose to include git configuration"
    echo "  3. Your containers will have git pre-configured!"
    echo ""
    
    log "Useful commands:"
    echo -e "  • To reconfigure: ${YELLOW}$0${NC}"
    echo -e "  • To clear config: ${YELLOW}$0 --clear${NC}"
}

# Clear configuration
clear_configuration() {
    log "Clearing AI DevKit Git configuration..."
    echo ""
    
    if [[ -d "$CONFIG_DIR" ]]; then
        info "This will remove:"
        echo "  • Container git configuration"
        echo "  • Stored GitHub credentials"
        echo "  • GitHub CLI configuration"
        echo ""
        read -p "Are you sure you want to delete all stored configuration? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$CONFIG_DIR"
            success "Configuration cleared"
        else
            info "Configuration unchanged"
        fi
    else
        info "No configuration found"
    fi
}

# Main execution
main() {
    print_banner
    
    # Handle command line arguments
    case "${1:-}" in
        --clear|-c)
            clear_configuration
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -c, --clear    Clear all stored container git configuration"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "This script creates an isolated git configuration for AI DevKit"
            echo "containers using HTTPS authentication with GitHub Personal Access Tokens."
            echo ""
            echo "The configuration is stored in ~/.ai-devkit/ and includes:"
            echo "  • Git user name and email"
            echo "  • GitHub Personal Access Token"
            echo "  • GitHub CLI configuration"
            echo ""
            echo "This configuration is completely isolated from your host git setup"
            echo "and is dynamically-injected by the AI DevKit Build Configurator"
            echo "into AI DevKit pods."
            exit 0
            ;;
    esac
    
    # Check for existing configuration
    if check_existing_config; then
        echo ""
        success "Existing configuration detected!"
        show_summary
        echo ""
        read -p "Do you want to reconfigure? (y/N): " -n 1 -r
        echo ""
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
        echo ""
    fi
    
    # Create directories
    create_directories
    
    # Run configuration steps
    configure_git_user
    configure_github_pat
    
    # Show summary
    show_summary
}

# Run main function
main "$@"
