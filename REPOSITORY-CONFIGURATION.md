# AI DevKit Repository Configuration System

## Overview

The AI DevKit Pod Configurator now includes a comprehensive repository configuration system that allows you to configure custom artifact repositories for your development components. This system supports Nexus Repository Manager, custom registries, and remote repositories with full authentication support.

## Key Features

- **Integrated Configuration**: Single script handles both container runtime and repository configuration
- **Menu-Based Interface**: Simple navigation through repository configuration options
- **Component-Specific Configuration**: Each component can have its own set of repositories
- **Multiple Repository Types**: Support for local (Nexus), remote, and custom repositories
- **Authentication Support**: Basic auth, token auth, and anonymous access
- **Format Support**: PyPI, NPM, Go, Maven, Cargo, RubyGems
- **Recommended Repositories**: Components provide recommended repository configurations
- **Build-Time Integration**: Repository settings are applied during container build
- **Runtime Configuration**: Settings can be applied inside running containers

## Quick Start

1. **Run the unified configuration script**:
   ```bash
   ./configure-ai-devkit.sh
   ```
   This will configure both:
   - Container runtime (Docker, Podman, nerdctl)
   - Repository managers (Nexus, PyPI, NPM, etc.)

2. **Build Components** with repository support:
   ```bash
   ./build-and-deploy.sh
   ```

## Repository Configuration Process

### Step 1: Component Discovery

The system automatically scans all component YAML files to identify those that support repository configuration. Components must have the following structure:

```yaml
installation:
  repos:
    enabled: true
    format: "pypi"  # or npm, go, maven2, cargo, rubygems
    config_type: "file"  # or env, both
    recommended:
      - name: "PyPI"
        url: "https://pypi.org"
        type: "remote"
        reason: "Official Python Package Index"
```

### Step 2: Nexus Configuration (Optional)

If you have a Nexus Repository Manager, you can configure it:

```
=== Nexus Repository Manager Configuration ===

Do you want to configure a Nexus repository manager? (y/N): y
Enter Nexus URL: http://nexus.example.com:8081
Select authentication type:
  1) Anonymous
  2) Basic authentication
  3) Token authentication
```

The system will fetch and cache the list of available repositories from your Nexus instance.

### Step 3: Component Repository Configuration

The configuration script presents a menu-based interface:

```
=== Component Repository Configuration ===

Select a component to configure repositories:

  1) Node.js 20.x LTS (npm) - 0 repositories configured
  2) Python 3.11 (pypi) - 0 repositories configured
  3) Maven (maven2) - 0 repositories configured

  S) Save and exit
  Q) Quit without saving

Select option: _
```

For each component, you can:
1. Use recommended repositories
2. Use Nexus repositories (if configured)
3. Configure custom repositories
4. Clear configuration

## Configuration Storage

### Configuration Files

All configuration is stored in `~/.ai-devkit/`:

1. **config.yaml**: Main configuration file
   ```yaml
   nexus:
     enabled: true
     url: "http://nexus.example.com:8081"
     auth:
       type: "basic"
       username: "admin"
       password: "encrypted:base64string"
   
   component_repos:
     NODEJS_20:
       - name: "npm-proxy"
         url: "http://nexus.example.com:8081/repository/npm-proxy/"
         type: "local_readonly"
         auth: "inherit"
         primary: true
   ```

2. **nexus-cache.yaml**: Cached Nexus repository list
   ```yaml
   nexus:
     url: "http://nexus.example.com:8081"
     last_fetched: "2024-01-15T10:30:00Z"
     repositories:
       - name: "npm-proxy"
         type: "proxy"
         format: "npm"
         url: "http://nexus.example.com:8081/repository/npm-proxy/"
   ```

## Repository Types

### 1. Local ReadOnly (Proxy/Group)
- Nexus proxy or group repositories
- Read-only access to cached packages
- May require authentication

### 2. Local ReadWrite (Hosted)
- Nexus hosted repositories
- Can publish packages
- Typically requires authentication

### 3. Remote (External)
- Public registries (PyPI, NPM, etc.)
- Private external registries
- May require authentication

## Supported Formats

| Format | Language/Tool | Config Method | Example Repositories |
|--------|--------------|---------------|---------------------|
| pypi | Python | pip.conf + env | PyPI, Test PyPI |
| npm | Node.js | .npmrc | NPM Registry, Yarn |
| go | Go | Environment vars | Go Proxy, Go Sum DB |
| maven2 | Java/Scala | settings.xml | Maven Central, JCenter |
| cargo | Rust | config.toml | Crates.io |
| rubygems | Ruby | .gemrc | RubyGems.org |

## Build Integration

When building components, the system:

1. Reads component repository configuration
2. Generates format-specific build arguments
3. Passes them to the container build process

Example for Python:
```bash
--build-arg PIP_INDEX_URL=http://nexus.local:8081/repository/pypi-proxy/simple
--build-arg PIP_TRUSTED_HOST=nexus.local
--build-arg PIP_EXTRA_INDEX_URL="https://pypi.org/simple"
```

## Runtime Configuration

The entrypoint script applies repository configuration at container startup:

1. Reads mounted configuration from `/config/component_repos.yaml`
2. Generates appropriate config files (.npmrc, pip.conf, etc.)
3. Sets environment variables (GOPROXY, etc.)
4. Ensures proper file ownership

## Testing the System

Run the test script to verify your installation:

```bash
./test-repository-config.sh
```

This will test:
- Component discovery
- Configuration file generation
- Build integration
- Entrypoint integration

## Troubleshooting

### No Components Found

Ensure component YAML files have the repos section:
```yaml
installation:
  repos:
    enabled: true
    format: "pypi"
```

### Nexus Connection Failed

Check:
- Nexus URL is correct
- Nexus is accessible from your machine
- Authentication credentials are correct
- Firewall/proxy settings

### Repository Not Applied

Verify:
- Component is in the selected components list
- Repository configuration is saved in config.yaml
- Build process reads the configuration
- No build cache is being used

## Advanced Usage

### Custom Repository Authentication

For repositories requiring special authentication:

1. Select "Add Custom Repository" (Enter key in right panel)
2. Provide repository details
3. Choose authentication method
4. Credentials are encrypted and stored securely

### Multiple Repository Priorities

- **Primary Repository**: Used as the main source
- **Secondary Repositories**: Fallback sources
- Mark one repository as primary per component

### Environment Variable Override

Legacy environment variables still work:
- `PIP_INDEX_URL`
- `NPM_REGISTRY`
- `GOPROXY`

These are applied if no component-specific configuration exists.

## Migration from Old System

If you have existing Nexus configuration:

1. The new system will read legacy config
2. It falls back to old format if no component repos configured
3. Gradually migrate components to new format

## Security Considerations

- Passwords are base64 encoded (not encrypted) in config
- Use mounted secrets for production environments
- Config files have restricted permissions (600)
- Never commit config.yaml to version control

## Contributing

To add repository support to a new component:

1. Add repos section to component YAML
2. Define format and recommended repositories
3. Update component's dockerfile to use build args
4. Update entrypoint to apply runtime config

## Support

For issues or questions:
- Check test script output: `./test-repository-config.sh`
- Review configuration: `cat ~/.ai-devkit/config.yaml`
- Check component YAML: `grep -A20 "repos:" components/languages/*.yaml`