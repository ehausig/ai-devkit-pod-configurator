#!/bin/bash
# Repository Configuration for Entrypoint
# This script fragment handles runtime repository configuration

# Function to setup component repositories at runtime
setup_component_repos() {
    local component_id="$1"
    local config_file="/config/component_repos.yaml"
    
    # Check if repository configuration is mounted
    if [[ ! -f "$config_file" ]]; then
        return
    fi
    
    echo "Setting up repository configuration for ${component_id}..."
    
    # Get repository configuration for this component
    if command -v yq >/dev/null 2>&1; then
        local repos=$(yq ".${component_id}" "$config_file" 2>/dev/null)
        
        if [[ -n "$repos" ]] && [[ "$repos" != "null" ]]; then
            # Get primary repository URL
            local primary_url=$(echo "$repos" | yq '.[] | select(.primary == true) | .url' 2>/dev/null | head -1)
            local format=$(yq ".${component_id}_format" "$config_file" 2>/dev/null)
            
            case "$format" in
                "pypi")
                    setup_pip_repos "$primary_url" "$repos"
                    ;;
                "npm")
                    setup_npm_repos "$primary_url" "$repos"
                    ;;
                "go")
                    setup_go_repos "$primary_url" "$repos"
                    ;;
                "maven2")
                    setup_maven_repos "$primary_url" "$repos"
                    ;;
                "cargo")
                    setup_cargo_repos "$primary_url" "$repos"
                    ;;
                "rubygems")
                    setup_gem_repos "$primary_url" "$repos"
                    ;;
            esac
        fi
    fi
}

# Setup pip repositories
setup_pip_repos() {
    local primary_url="$1"
    local repos="$2"
    
    if [[ -z "$primary_url" ]]; then
        return
    fi
    
    # Create pip config directory
    mkdir -p /home/devuser/.config/pip
    
    # Generate pip.conf
    cat > /home/devuser/.config/pip/pip.conf << EOF
[global]
index-url = ${primary_url}/simple
EOF
    
    # Add extra index URLs if present
    local extra_urls=$(echo "$repos" | yq '.[] | select(.primary != true) | .url' 2>/dev/null)
    if [[ -n "$extra_urls" ]]; then
        echo "extra-index-url =" >> /home/devuser/.config/pip/pip.conf
        while IFS= read -r url; do
            echo "    ${url}/simple" >> /home/devuser/.config/pip/pip.conf
        done <<< "$extra_urls"
    fi
    
    # Add trusted hosts
    local host=$(echo "$primary_url" | sed -E 's|https?://([^:/]+).*|\1|')
    echo "trusted-host = $host" >> /home/devuser/.config/pip/pip.conf
    
    chown -R devuser:devuser /home/devuser/.config/pip
    echo "✓ Configured pip repositories"
}

# Setup npm repositories
setup_npm_repos() {
    local primary_url="$1"
    local repos="$2"
    
    if [[ -z "$primary_url" ]]; then
        return
    fi
    
    # Create .npmrc
    cat > /home/devuser/.npmrc << EOF
registry=${primary_url}
EOF
    
    # Add authentication if needed
    local auth=$(echo "$repos" | yq '.[] | select(.primary == true) | .auth' 2>/dev/null | head -1)
    if [[ "$auth" == "basic" ]] && [[ -f /secrets/nexus-creds ]]; then
        source /secrets/nexus-creds
        echo "_auth=$(echo -n ${NEXUS_USER}:${NEXUS_PASS} | base64)" >> /home/devuser/.npmrc
    fi
    
    chown devuser:devuser /home/devuser/.npmrc
    echo "✓ Configured npm repositories"
}

# Setup Go proxy
setup_go_repos() {
    local primary_url="$1"
    local repos="$2"
    
    if [[ -z "$primary_url" ]]; then
        return
    fi
    
    # Build proxy list
    local proxy_list="${primary_url}"
    local extra_urls=$(echo "$repos" | yq '.[] | select(.primary != true) | .url' 2>/dev/null)
    while IFS= read -r url; do
        [[ -n "$url" ]] && proxy_list="${proxy_list},${url}"
    done <<< "$extra_urls"
    
    # Add to bashrc
    cat >> "$BASHRC" << EOF

# Go proxy configuration
export GOPROXY="${proxy_list},direct"
export GOPRIVATE=""
export GONOSUMDB=""
EOF
    
    echo "✓ Configured Go proxy"
}

# Setup Maven repositories
setup_maven_repos() {
    local primary_url="$1"
    local repos="$2"
    
    if [[ -z "$primary_url" ]]; then
        return
    fi
    
    # Create .m2 directory
    mkdir -p /home/devuser/.m2
    
    # Generate settings.xml
    cat > /home/devuser/.m2/settings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                              http://maven.apache.org/xsd/settings-1.0.0.xsd">
    <profiles>
        <profile>
            <id>nexus</id>
            <repositories>
EOF
    
    # Add primary repository
    cat >> /home/devuser/.m2/settings.xml << EOF
                <repository>
                    <id>central</id>
                    <url>${primary_url}</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                </repository>
EOF
    
    # Add extra repositories
    local i=1
    local extra_urls=$(echo "$repos" | yq '.[] | select(.primary != true) | .url' 2>/dev/null)
    while IFS= read -r url; do
        if [[ -n "$url" ]]; then
            cat >> /home/devuser/.m2/settings.xml << EOF
                <repository>
                    <id>repo${i}</id>
                    <url>${url}</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>false</enabled></snapshots>
                </repository>
EOF
            ((i++))
        fi
    done <<< "$extra_urls"
    
    cat >> /home/devuser/.m2/settings.xml << 'EOF'
            </repositories>
        </profile>
    </profiles>
    <activeProfiles>
        <activeProfile>nexus</activeProfile>
    </activeProfiles>
</settings>
EOF
    
    chown -R devuser:devuser /home/devuser/.m2
    echo "✓ Configured Maven repositories"
}

# Setup Cargo repositories
setup_cargo_repos() {
    local primary_url="$1"
    local repos="$2"
    
    if [[ -z "$primary_url" ]]; then
        return
    fi
    
    # Create .cargo directory
    mkdir -p /home/devuser/.cargo
    
    # Generate config.toml
    cat > /home/devuser/.cargo/config.toml << EOF
[source.crates-io]
replace-with = "custom"

[source.custom]
registry = "sparse+${primary_url}/"
EOF
    
    chown -R devuser:devuser /home/devuser/.cargo
    echo "✓ Configured Cargo repositories"
}

# Setup RubyGems repositories
setup_gem_repos() {
    local primary_url="$1"
    local repos="$2"
    
    if [[ -z "$primary_url" ]]; then
        return
    fi
    
    # Create .gemrc
    cat > /home/devuser/.gemrc << EOF
:sources:
  - ${primary_url}
EOF
    
    # Add extra sources
    local extra_urls=$(echo "$repos" | yq '.[] | select(.primary != true) | .url' 2>/dev/null)
    while IFS= read -r url; do
        [[ -n "$url" ]] && echo "  - ${url}" >> /home/devuser/.gemrc
    done <<< "$extra_urls"
    
    chown devuser:devuser /home/devuser/.gemrc
    echo "✓ Configured RubyGems repositories"
}

# Check for component repository configuration
if [[ -f /config/component_repos.yaml ]]; then
    echo "Found component repository configuration"
    
    # Get list of installed components from environment or detection
    # This would be populated by the build process
    INSTALLED_COMPONENTS="${INSTALLED_COMPONENTS:-}"
    
    # Setup repositories for each installed component
    for component in $INSTALLED_COMPONENTS; do
        setup_component_repos "$component"
    done
fi

# Legacy environment variable support for backward compatibility
if [[ -n "$PIP_INDEX_URL" ]] && [[ ! -f /home/devuser/.config/pip/pip.conf ]]; then
    mkdir -p /home/devuser/.config/pip
    cat > /home/devuser/.config/pip/pip.conf << EOF
[global]
index-url = ${PIP_INDEX_URL}
trusted-host = ${PIP_TRUSTED_HOST}
EOF
    chown -R devuser:devuser /home/devuser/.config/pip
    echo "✓ Configured pip from environment variables"
fi

if [[ -n "$NPM_REGISTRY" ]] && [[ ! -f /home/devuser/.npmrc ]]; then
    echo "registry=${NPM_REGISTRY}" > /home/devuser/.npmrc
    chown devuser:devuser /home/devuser/.npmrc
    echo "✓ Configured npm from environment variables"
fi

if [[ -n "$GOPROXY" ]]; then
    cat >> "$BASHRC" << EOF

# Go proxy configuration from environment
export GOPROXY="${GOPROXY}"
export GOPRIVATE="${GOPRIVATE:-}"
export GONOSUMDB="${GONOSUMDB:-}"
EOF
    echo "✓ Configured Go proxy from environment variables"
fi