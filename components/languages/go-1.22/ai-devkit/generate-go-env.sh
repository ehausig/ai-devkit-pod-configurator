#!/bin/bash
# Go-specific environment configuration generator with authentication support
set -euo pipefail

# Input: YAML data with repositories and component_id
# Output: Generated go-env.sh file content

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

# Get repository count
repo_count=0
if [[ "$YQ_TYPE" == "kislyuk" ]]; then
    repo_count=$(echo "$YAML_DATA" | yq '.repositories | length' 2>/dev/null || echo "0")
else
    repo_count=$(echo "$YAML_DATA" | yq eval '.repositories | length' - 2>/dev/null || echo "0")
fi

# Generate Go environment configuration
{
    echo "#!/bin/bash"
    echo "# Go environment configuration"
    
    if [[ "$repo_count" -gt 0 ]]; then
        # Build GOPROXY from repositories
        echo -n 'export GOPROXY="'
        
        for (( i=0; i<repo_count; i++ )); do
            repo_url=$(yq_query "$YAML_DATA" ".repositories[$i].url // \"\"")
            auth_ref=$(yq_query "$YAML_DATA" ".repositories[$i].auth // \"\"")
            
            if [[ -n "$repo_url" ]] && [[ "$repo_url" != "null" ]] && [[ "$repo_url" != '""' ]]; then
                # Add comma separator if not first item
                if [[ $i -gt 0 ]]; then
                    echo -n ","
                fi
                
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
                        
                        for (( j=0; j<cred_count; j++ )); do
                            cred_id=""
                            if [[ "$YQ_TYPE" == "kislyuk" ]]; then
                                cred_id=$(echo "$creds_json" | yq -r ".[$j].id // \"\"" 2>/dev/null)
                            else
                                cred_id=$(echo "$creds_json" | yq eval ".[$j].id // \"\"" - 2>/dev/null)
                            fi
                            
                            if [[ "$cred_id" == "$auth_ref" ]]; then
                                if [[ "$YQ_TYPE" == "kislyuk" ]]; then
                                    username=$(echo "$creds_json" | yq -r ".[$j].username // \"\"" 2>/dev/null)
                                    password=$(echo "$creds_json" | yq -r ".[$j].password // \"\"" 2>/dev/null)
                                else
                                    username=$(echo "$creds_json" | yq eval ".[$j].username // \"\"" - 2>/dev/null)
                                    password=$(echo "$creds_json" | yq eval ".[$j].password // \"\"" - 2>/dev/null)
                                fi
                                break
                            fi
                        done
                        
                        # Generate URL with embedded credentials if found
                        if [[ -n "$username" ]] && [[ -n "$password" ]]; then
                            # Insert credentials into URL
                            if [[ "$repo_url" =~ ^https?:// ]]; then
                                # URL has protocol - insert credentials after protocol
                                protocol=$(echo "$repo_url" | grep -o '^https\?://')
                                rest=$(echo "$repo_url" | sed 's|^https\?://||')
                                auth_url="${protocol}${username}:${password}@${rest}"
                                echo -n "$auth_url"
                            else
                                # No protocol - add with credentials
                                echo -n "https://${username}:${password}@${repo_url}"
                            fi
                        else
                            echo "# WARNING: Credential reference '$auth_ref' not found in config" >&2
                            echo -n "$repo_url"
                        fi
                    else
                        echo "# WARNING: Config file not found, cannot resolve auth reference '$auth_ref'" >&2
                        echo -n "$repo_url"
                    fi
                else
                    # No auth needed
                    echo -n "$repo_url"
                fi
            fi
        done
        
        echo ',direct"'
    else
        echo 'export GOPROXY="https://proxy.golang.org,direct"'
    fi
    
    echo 'export GOSUMDB="sum.golang.org"'
    echo 'export GO111MODULE=on'
    echo ''
    echo '# Set up private module patterns if needed'
    echo '# export GOPRIVATE="example.com/private/*"'
} > "$OUTPUT_FILE"