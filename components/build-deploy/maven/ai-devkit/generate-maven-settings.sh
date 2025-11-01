#!/bin/bash
# Maven-specific settings.xml generator with authentication support
set -euo pipefail

# Input: YAML data with repositories and component_id
# Output: Generated settings.xml file content

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

# Generate Maven settings.xml content
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"'
    echo '          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
    echo '          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0'
    echo '                              http://maven.apache.org/xsd/settings-1.0.0.xsd">'
    
    if [[ "$repo_count" -gt 0 ]]; then
        echo '    <mirrors>'
        
        # Process each repository
        for (( i=0; i<repo_count; i++ )); do
            repo_name=$(yq_query "$YAML_DATA" ".repositories[$i].name // \"\"")
            repo_url=$(yq_query "$YAML_DATA" ".repositories[$i].url // \"\"")
            
            if [[ -n "$repo_name" ]] && [[ -n "$repo_url" ]]; then
                echo '        <mirror>'
                echo "            <id>$repo_name</id>"
                echo '            <mirrorOf>*</mirrorOf>'
                echo "            <url>$repo_url</url>"
                echo '        </mirror>'
            fi
        done
        
        echo '    </mirrors>'
        echo ''
        echo '    <servers>'
        
        # Process authentication for each repository
        for (( i=0; i<repo_count; i++ )); do
            repo_name=$(yq_query "$YAML_DATA" ".repositories[$i].name // \"\"")
            auth_ref=$(yq_query "$YAML_DATA" ".repositories[$i].auth // \"\"")
            
            if [[ -n "$repo_name" ]] && [[ -n "$auth_ref" ]] && [[ "$auth_ref" != "null" ]] && [[ "$auth_ref" != '""' ]]; then
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
                    
                    # Generate server configuration if credentials found
                    if [[ -n "$username" ]] && [[ -n "$password" ]]; then
                        echo '        <server>'
                        echo "            <id>$repo_name</id>"
                        echo "            <username>$username</username>"
                        echo "            <password>$password</password>"
                        echo '        </server>'
                    else
                        echo "# WARNING: Credential reference '$auth_ref' not found in config" >&2
                    fi
                else
                    echo "# WARNING: Config file not found, cannot resolve auth reference '$auth_ref'" >&2
                fi
            fi
        done
        
        echo '    </servers>'
    else
        echo '    <!-- Using Maven Central (default) -->'
        echo '    <mirrors>'
        echo '        <mirror>'
        echo '            <id>central</id>'
        echo '            <mirrorOf>*</mirrorOf>'
        echo '            <url>https://repo.maven.apache.org/maven2</url>'
        echo '        </mirror>'
        echo '    </mirrors>'
    fi
    
    echo ''
    echo '    <!-- Common profiles -->'
    echo '    <profiles>'
    echo '        <profile>'
    echo '            <id>development</id>'
    echo '            <properties>'
    echo '                <maven.compiler.source>17</maven.compiler.source>'
    echo '                <maven.compiler.target>17</maven.compiler.target>'
    echo '                <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>'
    echo '            </properties>'
    echo '        </profile>'
    echo '    </profiles>'
    echo ''
    echo '    <activeProfiles>'
    echo '        <activeProfile>development</activeProfile>'
    echo '    </activeProfiles>'
    echo '</settings>'
} > "$OUTPUT_FILE"