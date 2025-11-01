#!/bin/bash
# Node.js-specific npmrc generator with authentication support
set -euo pipefail

# Input: YAML data with repositories and component_id
# Output: Generated .npmrc file content

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

# Generate npmrc content
{
    if [[ -n "$registry" ]] && [[ "$registry" != "null" ]] && [[ "$registry" != '""' ]]; then
        echo "registry=$registry"
        
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
                
                # Generate auth configuration if credentials found
                if [[ -n "$username" ]] && [[ -n "$password" ]]; then
                    # Extract hostname from registry URL
                    host=$(echo "$registry" | sed 's|^https*://||; s|/.*||')
                    
                    # Create base64 auth token
                    auth_string="${username}:${password}"
                    auth_token=$(echo -n "$auth_string" | base64 -w 0 2>/dev/null || echo -n "$auth_string" | base64)
                    
                    # Add npm auth configuration
                    echo "//${host}/:_auth=${auth_token}"
                    echo "//${host}/:always-auth=true"
                    echo "email=${username}@example.com"
                fi
            fi
        fi
    else
        echo "# Using default npm registry"
        echo "registry=https://registry.npmjs.org/"
    fi
} > "$OUTPUT_FILE"