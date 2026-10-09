#!/bin/bash
# Python-specific pip.conf generator with authentication support
set -euo pipefail

# Input: YAML data with repositories and component_id
# Output: Generated pip.conf file content

# Get input data
YAML_DATA="${1:-}"
OUTPUT_FILE="${2:-/dev/stdout}"

if [[ -z "$YAML_DATA" ]]; then
    echo "Error: No YAML data provided" >&2
    exit 1
fi

# Detect yq version
YQ_TYPE="unknown"
yq_path=$(command -v yq 2>/dev/null)
if [[ -n "$yq_path" ]] && head -1 "$yq_path" 2>/dev/null | grep -q "python"; then
    YQ_TYPE="kislyuk"
else
    YQ_TYPE="mikefarah"
fi

# Helper function to query YAML
yq_query() {
    local data="$1"
    local query="$2"
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        echo "$data" | yq -r "$query" 2>/dev/null || echo ""
    else
        echo "$data" | yq eval "$query" - 2>/dev/null || echo ""
    fi
}

# Get the first repository
registry=$(yq_query "$YAML_DATA" '.repositories[0].url // ""')
auth_ref=$(yq_query "$YAML_DATA" '.repositories[0].auth // ""')
trusted_host=""

# Extract hostname from URL for trusted-host if http://
if [[ -n "$registry" ]] && [[ "$registry" =~ ^http:// ]]; then
    trusted_host=$(echo "$registry" | sed 's|http://||; s|/.*||; s|:.*||')
fi

# Generate pip.conf content
{
    echo "[global]"
    
    if [[ -n "$registry" ]] && [[ "$registry" != "null" ]] && [[ "$registry" != '""' ]]; then
        # If auth reference exists, resolve credentials from config file
        if [[ -n "$auth_ref" ]] && [[ "$auth_ref" != "null" ]] && [[ "$auth_ref" != '""' ]]; then
            # Config file is always at ~/.ai-devkit/config.yaml in runtime
            CONFIG_FILE="$HOME/.ai-devkit/config.yaml"
            
            if [[ -f "$CONFIG_FILE" ]]; then
                # Find matching credential
                username=""
                password=""
                
                # Get credentials array
                creds_json=""
                if [[ "$YQ_TYPE" == "kislyuk" ]]; then
                    creds_json=$(cat "$CONFIG_FILE" | yq '.credentials' 2>/dev/null || echo "[]")
                else
                    creds_json=$(yq eval '.credentials' "$CONFIG_FILE" 2>/dev/null || echo "[]")
                fi
                
                # Find credential with matching id
                cred_count=0
                if [[ "$YQ_TYPE" == "kislyuk" ]]; then
                    cred_count=$(echo "$creds_json" | yq 'length' 2>/dev/null || echo "0")
                else
                    cred_count=$(echo "$creds_json" | yq eval 'length' - 2>/dev/null || echo "0")
                fi
                
                for (( i=0; i<cred_count; i++ )); do
                    cred_id=""
                    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
                        cred_id=$(echo "$creds_json" | yq -r ".[$i].id // \"\"" 2>/dev/null)
                    else
                        cred_id=$(echo "$creds_json" | yq eval ".[$i].id // \"\"" - 2>/dev/null)
                    fi
                    
                    if [[ "$cred_id" == "$auth_ref" ]]; then
                        if [[ "$YQ_TYPE" == "kislyuk" ]]; then
                            username=$(echo "$creds_json" | yq -r ".[$i].username // \"\"" 2>/dev/null)
                            password=$(echo "$creds_json" | yq -r ".[$i].password // \"\"" 2>/dev/null)
                        else
                            username=$(echo "$creds_json" | yq eval ".[$i].username // \"\"" - 2>/dev/null)
                            password=$(echo "$creds_json" | yq eval ".[$i].password // \"\"" - 2>/dev/null)
                        fi
                        break
                    fi
                done
                
                # Generate URL with embedded credentials if found
                if [[ -n "$username" ]] && [[ -n "$password" ]]; then
                    # Insert credentials into URL
                    if [[ "$registry" =~ ^https?:// ]]; then
                        # URL has protocol - insert credentials after protocol
                        protocol=$(echo "$registry" | grep -o '^https\?://')
                        rest=$(echo "$registry" | sed 's|^https\?://||')
                        index_url="${protocol}${username}:${password}@${rest}"
                    else
                        # No protocol - add with credentials
                        index_url="https://${username}:${password}@${registry}"
                    fi
                    echo "index-url = $index_url"
                else
                    echo "# WARNING: Credential reference '$auth_ref' not found in config" >&2
                    echo "index-url = $registry"
                fi
            else
                echo "# WARNING: Config file not found, cannot resolve auth reference '$auth_ref'" >&2
                echo "index-url = $registry"
            fi
        else
            # No auth needed
            echo "index-url = $registry"
        fi
        
        # Add trusted host if needed
        if [[ -n "$trusted_host" ]]; then
            echo "trusted-host = $trusted_host"
        fi
        
        # Add extra index URLs for remaining repositories
        repo_count=$(yq_query "$YAML_DATA" '.repositories | length')
        if [[ "$repo_count" -gt 1 ]]; then
            echo ""
            echo "# Additional repositories"
            for (( i=1; i<repo_count; i++ )); do
                extra_url=$(yq_query "$YAML_DATA" ".repositories[$i].url // \"\"")
                extra_name=$(yq_query "$YAML_DATA" ".repositories[$i].name // \"\"")
                if [[ -n "$extra_url" ]] && [[ "$extra_url" != "null" ]]; then
                    echo "# $extra_name: $extra_url"
                fi
            done
        fi
    else
        echo "# No repositories configured"
        echo "index-url = https://pypi.org/simple"
    fi
} > "$OUTPUT_FILE"