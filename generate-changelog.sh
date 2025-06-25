#!/bin/bash
# generate-changelog.sh - Generate CHANGELOG.md from git history
# This script analyzes git commits and creates a changelog based on conventional commits

set -e

# Configuration
OUTPUT_FILE="CHANGELOG.md"
TEMP_FILE=".changelog.tmp"
DEFAULT_BRANCH="main"
REPO_URL=""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper functions
log() { echo -e "${YELLOW}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Function to parse commit type
get_commit_type() {
    local commit_msg="$1"
    local type=""
    
    if [[ "$commit_msg" =~ ^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.*\))?!?: ]]; then
        type=$(echo "$commit_msg" | sed -E 's/^([a-z]+)(\(.*\))?!?:.*/\1/')
    fi
    
    echo "$type"
}

# Function to check if commit is breaking change
is_breaking_change() {
    local commit_msg="$1"
    local commit_body="$2"
    
    if [[ "$commit_msg" =~ ^[a-z]+(\(.*\))?!: ]] || [[ "$commit_body" =~ "BREAKING CHANGE" ]]; then
        return 0
    fi
    return 1
}

# Function to extract PR number from commit message
get_pr_number() {
    local commit_msg="$1"
    if [[ "$commit_msg" =~ \#([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

# Function to get repository URL
get_repo_url() {
    local origin_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    
    # Convert SSH to HTTPS
    if [[ "$origin_url" =~ git@github.com:(.+)\.git ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}"
    elif [[ "$origin_url" =~ https://github.com/(.+)\.git ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to format commit entry
format_commit() {
    local commit_hash="$1"
    local commit_msg="$2"
    local author="$3"
    local pr_num="$4"
    
    # Remove conventional commit prefix
    local clean_msg=$(echo "$commit_msg" | sed -E 's/^[a-z]+(\(.*\))?!?: //')
    
    # Format entry
    local entry="- $clean_msg"
    
    # Add commit hash link if we have repo URL
    if [[ -n "$REPO_URL" ]]; then
        entry="$entry ([${commit_hash:0:7}]($REPO_URL/commit/$commit_hash))"
    else
        entry="$entry (${commit_hash:0:7})"
    fi
    
    # Add PR link if available
    if [[ -n "$pr_num" ]] && [[ -n "$REPO_URL" ]]; then
        entry="$entry ([#$pr_num]($REPO_URL/pull/$pr_num))"
    fi
    
    echo "$entry"
}

# Main changelog generation function
generate_changelog() {
    log "Generating changelog from git history..."
    
    # Get repository URL
    REPO_URL=$(get_repo_url)
    if [[ -n "$REPO_URL" ]]; then
        info "Repository: $REPO_URL"
    fi
    
    # Get all tags sorted by version
    local tags=($(git tag -l --sort=-version:refname))
    
    # Initialize arrays for different change types
    local breaking_changes=()
    local features=()
    local fixes=()
    local docs=()
    local other_changes=()
    
    # Start building changelog
    cat > "$TEMP_FILE" << EOF
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
    
    # Function to process commits between two refs
    process_commits() {
        local from_ref="$1"
        local to_ref="$2"
        local version_name="$3"
        
        # Clear arrays
        breaking_changes=()
        features=()
        fixes=()
        docs=()
        other_changes=()
        
        # Get commits between refs
        local commits=""
        if [[ -z "$from_ref" ]]; then
            commits=$(git log --pretty=format:"%H|%s|%b|%an|%ad" --date=short "$to_ref")
        else
            commits=$(git log --pretty=format:"%H|%s|%b|%an|%ad" --date=short "${from_ref}..${to_ref}")
        fi
        
        # Process each commit
        while IFS='|' read -r hash subject body author date; do
            [[ -z "$hash" ]] && continue
            
            local type=$(get_commit_type "$subject")
            local pr_num=$(get_pr_number "$subject")
            local entry=$(format_commit "$hash" "$subject" "$author" "$pr_num")
            
            # Check for breaking change
            if is_breaking_change "$subject" "$body"; then
                breaking_changes+=("$entry")
            elif [[ -n "$type" ]]; then
                case "$type" in
                    feat)
                        features+=("$entry")
                        ;;
                    fix)
                        fixes+=("$entry")
                        ;;
                    docs)
                        docs+=("$entry")
                        ;;
                    *)
                        other_changes+=("$entry")
                        ;;
                esac
            fi
        done <<< "$commits"
        
        # Get date for this version
        local version_date=""
        if [[ "$version_name" == "[Unreleased]" ]]; then
            version_date=""
        else
            version_date=" - $(git log -1 --format=%ad --date=short "$to_ref")"
        fi
        
        # Write section header
        echo -e "\n## $version_name$version_date" >> "$TEMP_FILE"
        
        # Write changes by category
        if [[ ${#breaking_changes[@]} -gt 0 ]]; then
            echo -e "\n### ⚠️ BREAKING CHANGES" >> "$TEMP_FILE"
            for change in "${breaking_changes[@]}"; do
                echo "$change" >> "$TEMP_FILE"
            done
        fi
        
        if [[ ${#features[@]} -gt 0 ]]; then
            echo -e "\n### 🚀 Features" >> "$TEMP_FILE"
            for change in "${features[@]}"; do
                echo "$change" >> "$TEMP_FILE"
            done
        fi
        
        if [[ ${#fixes[@]} -gt 0 ]]; then
            echo -e "\n### 🐛 Bug Fixes" >> "$TEMP_FILE"
            for change in "${fixes[@]}"; do
                echo "$change" >> "$TEMP_FILE"
            done
        fi
        
        if [[ ${#docs[@]} -gt 0 ]]; then
            echo -e "\n### 📚 Documentation" >> "$TEMP_FILE"
            for change in "${docs[@]}"; do
                echo "$change" >> "$TEMP_FILE"
            done
        fi
        
        if [[ ${#other_changes[@]} -gt 0 ]]; then
            echo -e "\n### 🔧 Other Changes" >> "$TEMP_FILE"
            for change in "${other_changes[@]}"; do
                echo "$change" >> "$TEMP_FILE"
            done
        fi
    }
    
    # Process unreleased changes (from last tag to HEAD)
    if [[ ${#tags[@]} -gt 0 ]]; then
        process_commits "${tags[0]}" "HEAD" "[Unreleased]"
    else
        # No tags, process all commits
        process_commits "" "HEAD" "[Unreleased]"
    fi
    
    # Process changes between tags
    for i in "${!tags[@]}"; do
        local current_tag="${tags[$i]}"
        local previous_tag=""
        
        if [[ $((i + 1)) -lt ${#tags[@]} ]]; then
            previous_tag="${tags[$((i + 1))]}"
        fi
        
        process_commits "$previous_tag" "$current_tag" "[$current_tag]"
    done
    
    # Add footer
    if [[ -n "$REPO_URL" ]]; then
        echo -e "\n---\n" >> "$TEMP_FILE"
        echo "Generated from git history. For more details, see the [commit history]($REPO_URL/commits/$DEFAULT_BRANCH)." >> "$TEMP_FILE"
    fi
    
    # Move temp file to output
    mv "$TEMP_FILE" "$OUTPUT_FILE"
    success "Changelog generated: $OUTPUT_FILE"
}

# Function to show usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate CHANGELOG.md from git commit history using conventional commits.

OPTIONS:
    -h, --help          Show this help message
    -o, --output FILE   Output file (default: CHANGELOG.md)
    -b, --branch NAME   Default branch name (default: main)
    --dry-run          Show what would be generated without writing file

EXAMPLES:
    $0                  Generate CHANGELOG.md
    $0 -o HISTORY.md    Generate HISTORY.md
    $0 --dry-run       Preview changelog without writing

CONVENTIONAL COMMIT TYPES:
    feat:     New features
    fix:      Bug fixes
    docs:     Documentation changes
    style:    Code style changes
    refactor: Code refactoring
    test:     Test additions/changes
    chore:    Maintenance tasks
    perf:     Performance improvements
    ci:       CI/CD changes
    build:    Build system changes
    revert:   Revert commits

BREAKING CHANGES:
    Use 'feat!:' or 'fix!:' or include "BREAKING CHANGE" in commit body
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -b|--branch)
            DEFAULT_BRANCH="$2"
            shift 2
            ;;
        --dry-run)
            OUTPUT_FILE="/dev/stdout"
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    error "Not in a git repository!"
fi

# Generate changelog
generate_changelog

# Show statistics
if [[ "$OUTPUT_FILE" != "/dev/stdout" ]]; then
    echo ""
    info "Statistics:"
    echo "  Total commits processed: $(git rev-list --count HEAD)"
    echo "  Total tags found: $(git tag -l | wc -l)"
    echo "  Changelog lines: $(wc -l < "$OUTPUT_FILE")"
fi
