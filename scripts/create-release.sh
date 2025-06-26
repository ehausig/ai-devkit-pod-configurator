#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
show_usage() {
    echo "Usage: $0 [major|minor|patch]"
    echo ""
    echo "Arguments:"
    echo "  major  - Bump major version (1.0.0 -> 2.0.0)"
    echo "  minor  - Bump minor version (1.0.0 -> 1.1.0)"
    echo "  patch  - Bump patch version (1.0.0 -> 1.0.1)"
    echo ""
    echo "If no argument is provided, you'll be prompted to choose."
    exit 1
}

# Check if we're on develop branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "develop" ]]; then
    print_error "You must be on the develop branch to create a release"
    print_info "Run: git checkout develop"
    exit 1
fi

# Check if working directory is clean
if [[ -n $(git status -s) ]]; then
    print_error "Working directory has uncommitted changes"
    print_info "Please commit or stash your changes first"
    exit 1
fi

# Pull latest changes
print_info "Pulling latest changes from origin/develop..."
git pull origin develop

# Get current version
CURRENT_VERSION=$(cat VERSION)
print_info "Current version: ${CURRENT_VERSION}"

# Parse current version
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Determine bump type
BUMP_TYPE=""
if [[ $# -eq 1 ]]; then
    case "$1" in
        major|minor|patch)
            BUMP_TYPE="$1"
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            print_error "Invalid argument: $1"
            show_usage
            ;;
    esac
else
    # Interactive mode
    echo ""
    echo "Which type of release is this?"
    echo "  1) Patch (${CURRENT_VERSION} → ${MAJOR}.${MINOR}.$((PATCH + 1)))"
    echo "     Bug fixes, documentation updates, minor tweaks"
    echo ""
    echo "  2) Minor (${CURRENT_VERSION} → ${MAJOR}.$((MINOR + 1)).0)"
    echo "     New features, backwards compatible changes"
    echo ""
    echo "  3) Major (${CURRENT_VERSION} → $((MAJOR + 1)).0.0)"
    echo "     Breaking changes, major new features"
    echo ""
    read -p "Select option [1-3]: " CHOICE
    
    case $CHOICE in
        1) BUMP_TYPE="patch" ;;
        2) BUMP_TYPE="minor" ;;
        3) BUMP_TYPE="major" ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
fi

# Calculate new version
case "$BUMP_TYPE" in
    patch)
        NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
        ;;
    minor)
        NEW_VERSION="${MAJOR}.$((MINOR + 1)).0"
        ;;
    major)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
esac

# Show what will happen
echo ""
print_warning "Release Summary:"
echo "  Current version: ${CURRENT_VERSION}"
echo "  New version:     ${NEW_VERSION}"
echo "  Bump type:       ${BUMP_TYPE}"
echo ""

# Get recent commits for context
print_info "Recent commits since last tag:"
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [[ -n "$LAST_TAG" ]]; then
    echo ""
    git log "${LAST_TAG}..HEAD" --oneline | head -10
    echo ""
else
    echo ""
    git log --oneline | head -10
    echo ""
fi

# Confirm
read -p "Continue with release v${NEW_VERSION}? [y/N]: " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Release cancelled"
    exit 0
fi

# Update VERSION file
print_info "Updating VERSION file..."
echo "$NEW_VERSION" > VERSION

# Generate changelog
print_info "Generating changelog..."
if [[ -f "./scripts/generate-changelog.sh" ]]; then
    ./scripts/generate-changelog.sh
else
    print_warning "generate-changelog.sh not found, skipping changelog generation"
fi

# Commit changes
print_info "Committing version bump..."
git add VERSION CHANGELOG.md 2>/dev/null || git add VERSION
git commit -m "chore: prepare release v${NEW_VERSION}"

# Push to develop
print_info "Pushing to origin/develop..."
git push origin develop

# Create PR
print_info "Creating pull request..."
PR_BODY="## Release v${NEW_VERSION}

### Release Type: ${BUMP_TYPE}

This PR contains all changes for the v${NEW_VERSION} release.

### Changes
See [CHANGELOG.md](./CHANGELOG.md) for detailed changes.

### Post-merge checklist
- [ ] Tag the release: \`git tag -a v${NEW_VERSION} -m \"Release v${NEW_VERSION}\"\`
- [ ] Push the tag: \`git push origin v${NEW_VERSION}\`
- [ ] Create GitHub release
- [ ] Merge main back to develop"

PR_URL=$(gh pr create --base main --head develop \
    --title "chore: release v${NEW_VERSION}" \
    --body "$PR_BODY" \
    --web 2>&1 | grep -o 'https://.*' || true)

if [[ -n "$PR_URL" ]]; then
    print_success "Pull request created: ${PR_URL}"
else
    print_success "Pull request created!"
fi

# Create post-merge script
POST_MERGE_SCRIPT="release-v${NEW_VERSION}-post-merge.sh"
cat > "$POST_MERGE_SCRIPT" << EOF
#!/bin/bash
set -e

echo "Completing release v${NEW_VERSION}..."

# Checkout and update main
git checkout main
git pull origin main

# Create and push tag
git tag -a v${NEW_VERSION} -m "Release v${NEW_VERSION}"
git push origin v${NEW_VERSION}

# Create GitHub release
gh release create v${NEW_VERSION} \\
    --title "v${NEW_VERSION}" \\
    --notes-file CHANGELOG.md \\
    --target main

# Merge main back to develop
git checkout develop
git pull origin main
git push origin develop

echo "✅ Release v${NEW_VERSION} completed!"

# Clean up this script
rm -f "$POST_MERGE_SCRIPT"
EOF

chmod +x "$POST_MERGE_SCRIPT"

echo ""
print_success "Release preparation completed!"
echo ""
print_info "Next steps:"
echo "  1. Review and merge the PR"
echo "  2. Run the post-merge script: ./${POST_MERGE_SCRIPT}"
echo ""
print_warning "The post-merge script will self-delete after running."
