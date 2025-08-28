#!/bin/bash

# Repository Configuration Functions
# This library provides generic functions for repository configuration
# Language-specific logic has been moved to component-config-generator.sh

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration paths
CONFIG_DIR="$HOME/.ai-devkit"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
NEXUS_CACHE="$CONFIG_DIR/nexus-cache.yaml"
TEMP_CONFIG="/tmp/ai-devkit-config-$$"

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Function to read configuration values
read_config() {
    local key="$1"
    local config_file="${CONFIG_FILE}"
    
    if [[ ! -f "$config_file" ]]; then
        return
    fi
    
    if command -v yq >/dev/null 2>&1; then
        yq ".${key}" "$config_file" 2>/dev/null | grep -v "^null$"
    else
        # Fallback to basic parsing
        grep "^${key}:" "$config_file" 2>/dev/null | cut -d: -f2- | xargs
    fi
}

# Function to find eligible components with repository support
find_eligible_components() {
    local eligible=()
    local component_dir="${1:-components}"
    
    # Find all component YAML files
    while IFS= read -r yaml_file; do
        # Check if repos.enabled = true using yq
        if command -v yq >/dev/null 2>&1; then
            local enabled=$(yq '.installation.repos.enabled' "$yaml_file" 2>/dev/null)
            if [[ "$enabled" == "true" ]]; then
                local id=$(yq '.id' "$yaml_file" 2>/dev/null)
                local name=$(yq '.name' "$yaml_file" 2>/dev/null)
                local format=$(yq '.installation.repos.format' "$yaml_file" 2>/dev/null)
                eligible+=("${id}:${name}:${format}:${yaml_file}")
            fi
        else
            # Fallback to grep if yq is not available
            if grep -q "repos:" "$yaml_file" && grep -q "enabled: true" "$yaml_file"; then
                local id=$(grep "^id:" "$yaml_file" | head -1 | cut -d: -f2 | xargs)
                local name=$(grep "^name:" "$yaml_file" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/"//g')
                local format=$(grep -A10 "repos:" "$yaml_file" | grep "format:" | head -1 | cut -d: -f2 | sed 's/^[[:space:]]*//' | tr -d '"')
                eligible+=("${id}:${name}:${format}:${yaml_file}")
            fi
        fi
    done < <(find "$component_dir" -name "*.yaml" -type f 2>/dev/null)
    
    printf '%s\n' "${eligible[@]}"
}

# Function to fetch Nexus repositories
fetch_nexus_repositories() {
    local nexus_url="$1"
    local auth_type="${2:-anonymous}"
    local username="$3"
    local password="$4"
    
    echo "Fetching repository list from Nexus..." >&2
    
    local auth_header=""
    if [[ "$auth_type" == "basic" ]]; then
        auth_header="-u ${username}:${password}"
    fi
    
    # Try to fetch repository list
    local response=$(curl -s $auth_header \
        --connect-timeout 5 \
        --max-time 10 \
        "${nexus_url}/service/rest/v1/repositories" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo -e "${RED}Failed to fetch repository list from Nexus${NC}" >&2
        return 1
    fi
    
    # Parse JSON response and extract repository information
    if command -v jq >/dev/null 2>&1; then
        echo "$response" | jq -r '.[] | "\(.name):\(.type):\(.format):\(.url)"' 2>/dev/null
    else
        # Basic parsing without jq
        echo "$response" | grep -oE '"name"\s*:\s*"[^"]+"|"type"\s*:\s*"[^"]+"|"format"\s*:\s*"[^"]+"|"url"\s*:\s*"[^"]+"' | \
            sed 's/"//g' | sed 's/[[:space:]]*:[[:space:]]*/:/g' | \
            awk 'BEGIN{RS=""} {
                for(i=1;i<=NF;i++) {
                    split($i,a,":");
                    if(a[1]=="name") name=a[2];
                    if(a[1]=="type") type=a[2];
                    if(a[1]=="format") format=a[2];
                    if(a[1]=="url") url=a[2];
                }
                print name":"type":"format":"url
            }'
    fi
}

# Function to cache Nexus repositories
cache_nexus_repositories() {
    local nexus_url="$1"
    shift
    local repos=("$@")
    
    cat > "$NEXUS_CACHE" << EOF
nexus:
  url: "$nexus_url"
  last_fetched: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  repositories:
EOF
    
    for repo in "${repos[@]}"; do
        IFS=':' read -r name type format url <<< "$repo"
        cat >> "$NEXUS_CACHE" << EOF
    - name: "$name"
      type: "$type"
      format: "$format"
      url: "$url"
EOF
    done
}

# Function to read cached Nexus repositories
read_nexus_cache() {
    if [[ -f "$NEXUS_CACHE" ]]; then
        if command -v yq >/dev/null 2>&1; then
            yq '.nexus.repositories[] | .name + ":" + .type + ":" + .format + ":" + .url' "$NEXUS_CACHE" 2>/dev/null
        else
            grep -E "name:|type:|format:|url:" "$NEXUS_CACHE" | \
                sed 's/^[[:space:]]*- //' | \
                sed 's/^[[:space:]]*//' | \
                sed 's/: /:/g' | \
                sed 's/"//g' | \
                awk 'BEGIN{ORS=""} {
                    if($0 ~ /^name:/) {name=substr($0,6)}
                    if($0 ~ /^type:/) {type=substr($0,6)}
                    if($0 ~ /^format:/) {format=substr($0,8)}
                    if($0 ~ /^url:/) {url=substr($0,5); print name":"type":"format":"url"\n"}
                }'
        fi
    fi
}

# Function to get recommended repositories for a component
get_recommended_repositories() {
    local component_file="$1"
    
    if command -v yq >/dev/null 2>&1; then
        yq '.installation.repos.recommended[] | .name + ":" + .url + ":" + .type + ":" + .reason' "$component_file" 2>/dev/null
    else
        # Basic parsing without yq
        awk '/recommended:/,/^[^ ]/ {
            if(/name:/) {gsub(/.*name: *"?|"?$/,""); name=$0}
            if(/url:/) {gsub(/.*url: *"?|"?$/,""); url=$0}
            if(/type:/) {gsub(/.*type: *"?|"?$/,""); type=$0}
            if(/reason:/) {gsub(/.*reason: *"?|"?$/,""); reason=$0; 
                print name":"url":"type":"reason}
        }' "$component_file"
    fi
}

# Function to save component repository configuration
save_component_repos() {
    local component_id="$1"
    shift
    local repos=("$@")
    
    # Create temporary config file if it doesn't exist
    if [[ ! -f "$TEMP_CONFIG" ]]; then
        echo "component_repos:" > "$TEMP_CONFIG"
    fi
    
    # Add component configuration
    cat >> "$TEMP_CONFIG" << EOF
  ${component_id}:
EOF
    
    for repo in "${repos[@]}"; do
        IFS='|' read -r name url type auth primary <<< "$repo"
        cat >> "$TEMP_CONFIG" << EOF
    - name: "$name"
      url: "$url"
      type: "$type"
      auth: "$auth"
      primary: $primary
EOF
    done
}

# Function to merge temporary config with existing config
merge_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Backup existing config
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        
        # Merge configs using yq if available
        if command -v yq >/dev/null 2>&1; then
            yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
                "$CONFIG_FILE" "$TEMP_CONFIG" > "${CONFIG_FILE}.tmp"
            mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        else
            # Simple append for basic merge
            cat "$TEMP_CONFIG" >> "$CONFIG_FILE"
        fi
    else
        # No existing config, just copy temp
        cp "$TEMP_CONFIG" "$CONFIG_FILE"
    fi
    
    # Clean up temp config
    rm -f "$TEMP_CONFIG"
}

# Function to encrypt password
encrypt_password() {
    echo -n "$1" | base64
}

# Function to decrypt password
decrypt_password() {
    echo -n "$1" | base64 -d
}

# Export functions
export -f read_config
export -f find_eligible_components
export -f fetch_nexus_repositories
export -f cache_nexus_repositories
export -f read_nexus_cache
export -f get_recommended_repositories
export -f save_component_repos
export -f merge_config
export -f encrypt_password
export -f decrypt_password