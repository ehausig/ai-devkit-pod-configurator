#!/bin/bash
# Pure Bash Template Processing Engine for Component Configuration
# No Python dependencies - uses yq v4 (Go-based) for YAML processing

# Only set strict mode if not being sourced interactively
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

# Detect yq version and set appropriate command
# Try to find yq in common locations
if command -v yq >/dev/null 2>&1; then
    YQ=$(command -v yq)
elif [[ -x /usr/local/bin/yq ]]; then
    YQ=/usr/local/bin/yq
elif [[ -x /usr/bin/yq ]]; then
    YQ=/usr/bin/yq
else
    echo "Warning: yq not found, using 'yq' and hoping it's in PATH" >&2
    YQ=yq
fi

# Detect which version of yq we have
YQ_VERSION=$($YQ --version 2>&1 || true)
if echo "$YQ_VERSION" | grep -q "mikefarah"; then
    # Go-based yq (mikefarah/yq v4)
    YQ_TYPE="mikefarah"
    YQ_EVAL="$YQ eval"
elif echo "$YQ_VERSION" | grep -q "kislyuk\|jq wrapper\|yq 0"; then
    # Python-based yq (kislyuk/yq) - also matches "yq 0.0.0"
    YQ_TYPE="kislyuk"
    YQ_EVAL="$YQ -r"
else
    # Check if --help mentions jq
    YQ_HELP=$($YQ --help 2>&1 | head -5 || true)
    if echo "$YQ_HELP" | grep -q "jq"; then
        YQ_TYPE="kislyuk"
        YQ_EVAL="$YQ -r"
    else
        # Unknown, assume mikefarah syntax
        YQ_TYPE="mikefarah"
        YQ_EVAL="$YQ eval"
    fi
fi

# Source required libraries (with error handling)
# Get the directory of this script
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "$0" ]] && [[ "$0" != "-bash" ]] && [[ "$0" != "-zsh" ]]; then
    # Fallback for other shells
    SCRIPT_DIR="$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"
else
    # Last resort: assume we're in the repo root and libs are in ./lib
    if [[ -d "./lib" ]]; then
        SCRIPT_DIR="$(pwd)/lib"
    elif [[ -d "../lib" ]]; then
        SCRIPT_DIR="$(cd ../lib && pwd)"
    else
        SCRIPT_DIR="."
    fi
fi

# Check if required files exist before sourcing
if [[ -f "$SCRIPT_DIR/config-reader.sh" ]]; then
    source "$SCRIPT_DIR/config-reader.sh"
else
    echo "Warning: config-reader.sh not found at $SCRIPT_DIR" >&2
fi

if [[ -f "$SCRIPT_DIR/repository-loader.sh" ]]; then
    source "$SCRIPT_DIR/repository-loader.sh"
else
    echo "Warning: repository-loader.sh not found at $SCRIPT_DIR" >&2
fi

if [[ -f "$SCRIPT_DIR/credential-manager.sh" ]]; then
    source "$SCRIPT_DIR/credential-manager.sh"
else
    echo "Warning: credential-manager.sh not found at $SCRIPT_DIR" >&2
fi

# Helper function to query YAML with either yq version
yq_query() {
    local yaml_data="$1"
    local query="$2"
    local default="${3:-}"
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        # kislyuk/yq uses jq syntax
        local result=$(echo "$yaml_data" | $YQ -r "$query" 2>/dev/null || echo "null")
        if [[ "$result" == "null" ]] || [[ -z "$result" ]]; then
            echo "$default"
        else
            echo "$result"
        fi
    else
        # mikefarah/yq uses its own syntax
        local result=$(echo "$yaml_data" | $YQ eval "$query" - 2>/dev/null || echo "null")
        if [[ "$result" == "null" ]] || [[ -z "$result" ]]; then
            echo "$default"
        else
            echo "$result"
        fi
    fi
}

# Helper to count array items
yq_count() {
    local yaml_data="$1"
    local array_path="$2"
    
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        echo "$yaml_data" | $YQ -r "$array_path | length" 2>/dev/null || echo "0"
    else
        echo "$yaml_data" | $YQ eval "$array_path | length" - 2>/dev/null || echo "0"
    fi
}

# Process a simple template with bash variable substitution
process_template_bash() {
    local template_file="$1"  # Ignored for bash processor
    local data_yaml="$2"
    local output_file="$3"
    
    # Create output directory if needed
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Parse YAML data into bash variables
    local repositories=$(yq_query "$data_yaml" '.repositories')
    local component_id=$(yq_query "$data_yaml" '.component_id')
    local format=$(yq_query "$data_yaml" '.format')
    
    # Get first repository if exists
    local first_repo_url=""
    local first_repo_name=""
    local first_repo_auth=""
    if [[ -n "$repositories" ]] && [[ "$repositories" != "null" ]]; then
        first_repo_url=$(yq_query "$data_yaml" '.repositories[0].url // ""')
        first_repo_name=$(yq_query "$data_yaml" '.repositories[0].name // ""')
        first_repo_auth=$(yq_query "$data_yaml" '.repositories[0].auth // ""')
    fi
    
    # Extract hostname from URL for trusted-host
    local trusted_host=""
    if [[ -n "$first_repo_url" ]] && [[ "$first_repo_url" =~ ^http:// ]]; then
        # Extract hostname from http:// URL
        trusted_host=$(echo "$first_repo_url" | sed 's|http://||; s|/.*||; s|:.*||')
    fi
    
    # Process template based on format
    case "$format" in
        "pypi")
            generate_pip_config_bash "$data_yaml" "$output_file" "$trusted_host"
            ;;
        "npm")
            generate_npm_config_bash "$data_yaml" "$output_file"
            ;;
        "go")
            generate_go_env_bash "$data_yaml" "$output_file"
            ;;
        "maven2")
            generate_maven_settings_bash "$data_yaml" "$output_file"
            ;;
        "cargo")
            generate_cargo_config_bash "$data_yaml" "$output_file"
            ;;
        "gradle")
            generate_gradle_init_bash "$data_yaml" "$output_file"
            ;;
        "sbt")
            generate_sbt_repositories_bash "$data_yaml" "$output_file"
            ;;
        "gem")
            generate_gem_config_bash "$data_yaml" "$output_file"
            ;;
        *)
            # For unknown formats, copy template as-is
            cp "$template_file" "$output_file" 2>/dev/null || true
            ;;
    esac
    
    echo "Generated: $output_file"
    return 0
}

# Generate pip.conf using bash
generate_pip_config_bash() {
    local yaml_data="$1"
    local output_file="$2"
    local trusted_host="$3"
    
    # Check if component has its own pip.conf generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-pip-conf.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-pip-conf.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    # Fallback to generic pip.conf generation
    {
        echo "[global]"
        
        # Check if we have repositories
        local repo_count=$(yq_count "$yaml_data" '.repositories')
        if [[ "$repo_count" -gt 0 ]]; then
            # Get first repository as index-url
            local index_url=$(yq_query "$yaml_data" '.repositories[0].url' "")
            if [[ -n "$index_url" ]] && [[ "$index_url" != "null" ]]; then
                echo "index-url = $index_url"
                
                # Add trusted-host if http
                if [[ -n "$trusted_host" ]]; then
                    echo "trusted-host = $trusted_host"
                fi
                
                # Add extra-index-urls if more than one repo
                if [[ $repo_count -gt 1 ]]; then
                    echo "extra-index-url ="
                    for (( i=1; i<repo_count; i++ )); do
                        local url=$(yq_query "$yaml_data" ".repositories[$i].url" "")
                        if [[ -n "$url" ]] && [[ "$url" != "null" ]]; then
                            echo "    $url"
                        fi
                    done
                fi
            fi
        else
            echo "# No repositories configured"
            echo "index-url = https://pypi.org/simple"
        fi
    } > "$output_file"
}

# Generate .npmrc using bash
generate_npm_config_bash() {
    local yaml_data="$1"
    local output_file="$2"
    
    # Check if component has its own npmrc generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-npmrc.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-npmrc.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    # Fallback to generic npmrc generation
    {
        local registry=$(yq_query "$yaml_data" '.repositories[0].url // ""')
        
        if [[ -n "$registry" ]] && [[ "$registry" != "null" ]] && [[ "$registry" != '""' ]]; then
            echo "registry=$registry"
        else
            echo "# Using default npm registry"
            echo "registry=https://registry.npmjs.org/"
        fi
    } > "$output_file"
}

# Generate go-env.sh using bash
generate_go_env_bash() {
    local yaml_data="$1"
    local output_file="$2"
    
    # Check if component has its own go-env generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-go-env.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-go-env.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    {
        echo "#!/bin/bash"
        echo "# Go environment configuration"
        
        # Build GOPROXY from all repository URLs
        local repo_count=$(yq_count "$yaml_data" '.repositories')
        if [[ "$repo_count" -gt 0 ]]; then
            local goproxy=""
            for (( i=0; i<repo_count; i++ )); do
                local url=$(yq_query "$yaml_data" ".repositories[$i].url // \"\"")
                if [[ -n "$url" ]] && [[ "$url" != "null" ]] && [[ "$url" != '""' ]]; then
                    if [[ -n "$goproxy" ]]; then
                        goproxy="${goproxy},"
                    fi
                    goproxy="${goproxy}${url}"
                fi
            done
            if [[ -n "$goproxy" ]]; then
                echo "export GOPROXY=\"${goproxy},direct\""
            else
                echo "export GOPROXY=\"https://proxy.golang.org,direct\""
            fi
        else
            echo "export GOPROXY=\"https://proxy.golang.org,direct\""
        fi
        
        echo "export GOSUMDB=\"sum.golang.org\""
        echo "export GO111MODULE=on"
    } > "$output_file"
}

# Generate Maven settings.xml using bash
generate_maven_settings_bash() {
    local yaml_data="$1"
    local output_file="$2"
    
    # Check if component has its own maven settings generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-maven-settings.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-maven-settings.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"'
        echo '          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
        echo '          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0'
        echo '                              http://maven.apache.org/xsd/settings-1.0.0.xsd">'
        
        local repo_count=$(yq_count "$yaml_data" '.repositories')
        if [[ "$repo_count" -gt 0 ]]; then
            echo "    <mirrors>"
            for (( i=0; i<repo_count; i++ )); do
                local name=$(yq_query "$yaml_data" ".repositories[$i].name // \"\"")
                local url=$(yq_query "$yaml_data" ".repositories[$i].url // \"\"")
                if [[ -n "$url" ]] && [[ "$url" != "null" ]] && [[ "$url" != '""' ]]; then
                    echo "        <mirror>"
                    echo "            <id>${name:-repo}</id>"
                    echo "            <mirrorOf>*</mirrorOf>"
                    echo "            <url>$url</url>"
                    echo "        </mirror>"
                fi
            done
            echo "    </mirrors>"
        else
            echo "    <!-- Using Maven Central (default) -->"
            echo "    <mirrors>"
            echo "        <mirror>"
            echo "            <id>central</id>"
            echo "            <mirrorOf>*</mirrorOf>"
            echo "            <url>https://repo.maven.apache.org/maven2</url>"
            echo "        </mirror>"
            echo "    </mirrors>"
        fi
        
        echo "</settings>"
    } > "$output_file"
}

# Generate Cargo config.toml using bash
generate_cargo_config_bash() {
    local yaml_data="$1"
    local output_file="$2"
    
    # Check if component has its own cargo config generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-cargo-config.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-cargo-config.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    {
        echo "# Cargo configuration"
        
        local registry=$(yq_query "$yaml_data" '.repositories[0].url // ""')
        if [[ -n "$registry" ]] && [[ "$registry" != "null" ]] && [[ "$registry" != '""' ]]; then
            echo "[source.crates-io]"
            echo "replace-with = \"custom\""
            echo ""
            echo "[source.custom]"
            echo "registry = \"$registry\""
        else
            echo "# Using default crates.io registry"
            echo "[source.crates-io]"
            echo "registry = \"https://github.com/rust-lang/crates.io-index\""
        fi
    } > "$output_file"
}

# Generate Gradle init.gradle using bash
generate_gradle_init_bash() {
    local yaml_data="$1"
    local output_file="$2"
    
    # Check if component has its own gradle init generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-gradle-init.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-gradle-init.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    {
        echo "// Gradle init script for repository configuration"
        echo "allprojects {"
        echo "    repositories {"
        
        local repo_count=$(yq_count "$yaml_data" '.repositories')
        if [[ "$repo_count" -gt 0 ]]; then
            for (( i=0; i<repo_count; i++ )); do
                local name=$(yq_query "$yaml_data" ".repositories[$i].name // \"\"")
                local url=$(yq_query "$yaml_data" ".repositories[$i].url // \"\"")
                if [[ -n "$url" ]] && [[ "$url" != "null" ]] && [[ "$url" != '""' ]]; then
                    echo "        maven {"
                    echo "            name = '${name:-repo}'"
                    echo "            url = '$url'"
                    echo "        }"
                fi
            done
        else
            echo "        // Default repositories"
            echo "        mavenCentral()"
            echo "        google()"
        fi
        
        echo "    }"
        echo "}"
    } > "$output_file"
}

# Generate .gemrc using bash
generate_gem_config_bash() {
    local yaml_data="$1"
    local output_file="$2"
    
    # Check if component has its own gemrc generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-gemrc.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-gemrc.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    # Fallback to generic gemrc generation
    {
        echo "---"
        echo ":sources:"
        
        local repo_count=$(yq_count "$yaml_data" '.repositories')
        if [[ "$repo_count" -gt 0 ]]; then
            for (( i=0; i<repo_count; i++ )); do
                local url=$(yq_query "$yaml_data" ".repositories[$i].url // \"\"")
                if [[ -n "$url" ]] && [[ "$url" != "null" ]] && [[ "$url" != '""' ]]; then
                    echo "  - $url"
                fi
            done
        else
            echo "  - https://rubygems.org/"
        fi
    } > "$output_file"
}

# Generate SBT repositories using bash
generate_sbt_repositories_bash() {
    local yaml_data="$1"
    local output_file="$2"
    
    # Check if component has its own sbt repositories generator
    local component_id=$(yq_query "$yaml_data" '.component_id // ""')
    if [[ -n "$component_id" ]]; then
        # Find component directory
        local component_dir=""
        for type in languages build-deploy; do
            for comp in components/$type/*; do
                if [[ -d "$comp" ]] && [[ "$(basename "$comp" | tr '-' '_' | tr '[:lower:]' '[:upper:]')" == "$component_id" ]]; then
                    component_dir="$comp"
                    break 2
                fi
            done
        done
        
        # Check for component-specific generator
        if [[ -n "$component_dir" ]] && [[ -f "$component_dir/ai-devkit/generate-sbt-repositories.sh" ]]; then
            # Use component's generator
            "$component_dir/ai-devkit/generate-sbt-repositories.sh" "$yaml_data" "$output_file"
            return $?
        fi
    fi
    
    {
        echo "[repositories]"
        
        local repo_count=$(yq_count "$yaml_data" '.repositories')
        if [[ "$repo_count" -gt 0 ]]; then
            for (( i=0; i<repo_count; i++ )); do
                local name=$(yq_query "$yaml_data" ".repositories[$i].name // \"\"")
                local url=$(yq_query "$yaml_data" ".repositories[$i].url // \"\"")
                if [[ -n "$url" ]] && [[ "$url" != "null" ]] && [[ "$url" != '""' ]]; then
                    echo "${name:-repo}: $url"
                fi
            done
        else
            echo "# Default SBT repositories"
            echo "local"
            echo "maven-central: https://repo1.maven.org/maven2/"
        fi
    } > "$output_file"
}

# Wrapper function to maintain compatibility
process_template() {
    process_template_bash "$@"
}

# Generate configuration for a component (bash version)
generate_component_configuration() {
    local component_dir="$1"
    local component_id="$2"
    local output_dir="$3"
    
    echo "Processing component: $component_id" >&2
    
    # Check for component configuration
    local config_file="$component_dir/ai-devkit/config.yaml"
    if [[ ! -f "$config_file" ]]; then
        echo "No configuration metadata for $component_id, skipping" >&2
        return 0
    fi
    
    # Get repository format
    local format=""
    if [[ "$YQ_TYPE" == "kislyuk" ]]; then
        format=$($YQ -r '.configuration.format // ""' "$config_file" 2>/dev/null || echo "")
    else
        format=$($YQ eval '.configuration.format // ""' "$config_file" 2>/dev/null || echo "")
    fi
    
    if [[ -z "$format" ]] || [[ "$format" == "null" ]] || [[ "$format" == '""' ]]; then
        echo "No repository format for $component_id, skipping" >&2
        return 0
    fi
    
    # Load repositories for this component (returns JSON)
    local repos_json=$(resolve_repositories "$component_id")
    
    # Convert JSON to YAML for template data
    local repos_yaml=""
    if [[ -n "$repos_json" ]] && [[ "$repos_json" != "[]" ]]; then
        if [[ "$YQ_TYPE" == "kislyuk" ]]; then
            # kislyuk/yq can output YAML with -y
            repos_yaml=$(echo "$repos_json" | $YQ -y '.' 2>/dev/null || echo "[]")
        else
            # mikefarah/yq converts with -P
            repos_yaml=$(echo "$repos_json" | $YQ eval -P - 2>/dev/null || echo "[]")
        fi
    fi
    
    # Create YAML template data properly formatted
    # If repos_yaml is empty or just "[]", use empty array
    if [[ -z "$repos_yaml" ]] || [[ "$repos_yaml" == "[]" ]]; then
        local template_data=$(cat <<EOF
repositories: []
component_id: "$component_id"
format: "$format"
EOF
        )
    else
        # Properly indent the YAML array under repositories
        local indented_repos=$(echo "$repos_yaml" | sed 's/^/  /')
        local template_data=$(cat <<EOF
repositories:
$indented_repos
component_id: "$component_id"
format: "$format"
EOF
        )
    fi
    
    # Process template using bash version
    # Note: We ignore the actual template files since we use pure bash generation
    local output_file="$output_dir/config"
    
    # Determine output file name based on format
    case "$format" in
        "pypi") output_file="$output_dir/pip.conf" ;;
        "npm") output_file="$output_dir/npmrc" ;;
        "go") output_file="$output_dir/go-env.sh" ;;
        "maven2") output_file="$output_dir/settings.xml" ;;
        "cargo") output_file="$output_dir/cargo-config.toml" ;;
        "gradle") output_file="$output_dir/init.gradle" ;;
        "sbt") output_file="$output_dir/repositories" ;;
        "gem") output_file="$output_dir/gemrc" ;;
    esac
    
    # Pass null as template_file since bash processor ignores it
    process_template_bash "/dev/null" "$template_data" "$output_file"
    
    return 0
}

# Export functions for use by other scripts (bash only)
# Note: export -f is bash-specific and won't work in zsh/sh
if [[ -n "$BASH_VERSION" ]]; then
    export -f process_template 2>/dev/null || true
    export -f process_template_bash 2>/dev/null || true
    export -f generate_component_configuration 2>/dev/null || true
fi