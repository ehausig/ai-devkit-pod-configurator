# AI DevKit Pod Configurator

A powerful, modular system for creating containerized development environments in Kubernetes with support for multiple programming languages, build tools, and AI coding assistants.

![AI DevKit](https://img.shields.io/badge/AI%20DevKit-Pod%20Configurator-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-orange)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Compatible-326ce5)

## 📖 Documentation

- **[Architecture Overview](docs/architecture.md)** - System design and component structure
- **[Creating Components](docs/components.md)** - Build your own custom components
- **[Theme Customization](docs/themes.md)** - Customize the TUI appearance
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Roadmap](docs/roadmap.md)** - Future plans and enhancements

### For Contributors
- **[Developer Guide](docs/developer.md)** - Contributing code and creating pull requests
- **[Maintainer Guide](docs/maintainer.md)** - Release management and repository maintenance

## 🎯 Overview

AI DevKit Pod Configurator provides a beautiful TUI (Terminal User Interface) for selecting and deploying customized development environments in Kubernetes. Each environment is built from a minimal Ubuntu base with only the components you need.

### Key Features

- 🎨 **Beautiful TUI** - Interactive component selection with theme support
- 🧩 **Modular Architecture** - Add only what you need: languages, tools, AI assistants
- 🤖 **Autonomous AI Development** - Claude Code integration with self-directed multi-persona workflow
- 🔧 **Language Support** - Python, Java, Go, Rust, Ruby, Scala, Kotlin, and more
- 📦 **Build Tools** - Maven, Gradle, SBT with optional Nexus proxy support
- 🧪 **TUI Testing** - Microsoft TUI Test pre-installed for testing terminal apps
- 💾 **Persistent Storage** - Your code and configuration persist across restarts
- 🌐 **Web File Manager** - Built-in Filebrowser for easy file management
- 🔒 **Secure** - Runs as non-root user with proper isolation
- 📊 **Event-Sourced Memory** - Journal-based system for autonomous AI workflow

## 📸 Screenshots

### Component Selection Interface
![Component Selection Interface](docs/images/component-selection.png)
*Interactive TUI for selecting development tools and languages*

### Deployment Status Dashboard
![Deployment Status Dashboard - In Progress](docs/images/deployment-status.png)
*Real-time deployment progress with animated status indicators*

![Deployment Status Dashboard - Complete](docs/images/deployment-complete.png)
*Automatic port forwarding for easy connectivity*

### Development Environment
![Development Environment](docs/images/dev-environment.png)
*Inside the configured container with your selected tools ready to use*

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (k3s, minikube, Colima, or any Kubernetes distribution)
- kubectl configured to access your cluster
- Docker or compatible container runtime
- For macOS users: [Colima](https://github.com/abiosoft/colima) is recommended

### macOS Quick Setup with Colima

```bash
# Install Colima
brew install colima kubectl

# Start Colima with Kubernetes
colima start --kubernetes --cpu 4 --memory 8

# Verify setup
kubectl get nodes
```

### Basic Usage

```bash
# Clone the repository
git clone https://github.com/ehausig/ai-devkit-pod-configurator.git
cd ai-devkit-pod-configurator

# Make scripts executable
chmod +x *.sh

# (Optional) Configure git credentials for automatic injection
./configure-git-host.sh

# Build and deploy with interactive component selection
./build-and-deploy.sh

# Access your development environment
ssh devuser@localhost -p 2222
# Password: devuser
```

## 🎮 Using the Component Selector

When you run `./build-and-deploy.sh`, an interactive TUI appears:

- **↑/↓** or **j/k** - Navigate components
- **←/→** or **h/l** - Switch pages
- **SPACE** - Select/deselect component
- **TAB** - Switch between catalog and selected items
- **ENTER** - Build with selected components
- **q** - Quit

The selector shows:
- ✓ Selected components
- ○ Available components
- Dependencies and conflicts
- Real-time build status with animations

## 🤖 Claude Code Integration

### Autonomous AI Development System

The AI DevKit includes deep integration with Claude Code, featuring a revolutionary autonomous development system that enables end-to-end software creation without human intervention.

#### Event-Sourced Architecture
The system uses `~/workspace/JOURNAL.md` as an event store, implementing event sourcing patterns where all work, decisions, and state changes are recorded as immutable events. This provides:
- **Persistent Memory** - Survives context switches and session restarts
- **Complete Audit Trail** - Every decision and action is traceable
- **State Recovery** - Can reconstruct context from any point
- **Work Coordination** - Enables autonomous persona transitions

#### Autonomous Multi-Persona Workflow
Simulates a complete development team that works autonomously:
- **ARCHITECT** - System design and technical planning
- **DEVELOPER** - Implementation with TDD practices
- **QA** - Comprehensive testing and quality assurance
- **REVIEWER** - Code review and standards compliance
- **MERGER** - Integration and release management

📖 **[Detailed Autonomous System Documentation](components/agents/claude-code/personas/README.md)** - In-depth guide to the autonomous workflow

#### Autonomous Operation

To start an autonomous development session:

```bash
# SSH into your container
ssh devuser@localhost -p 2222

# Create a project prompt
cat > ~/workspace/PROMPT.md << 'EOF'
Create a REST API for a task management system with:
- User authentication
- CRUD operations for tasks
- PostgreSQL database
- Comprehensive tests
- Full documentation
EOF

# Initialize ARCHITECT to start autonomous development
/home/devuser/.claude/personas/architect/architect-init.sh
```

The system will autonomously:
1. Design the architecture (ARCHITECT)
2. Implement with TDD (DEVELOPER)
3. Test against real services (QA)
4. Review code quality (REVIEWER)
5. Merge and release (MERGER)

All without human intervention, using the journal for coordination.

#### Key Event Types
- `[WORK:PENDING]` - Work that needs to be done
- `[WORK:STARTED]` - Work has begun (prevents duplicate processing)
- `[WORK:COMPLETED]` - Work is finished
- `[WORK:BLOCKED]` - Work cannot proceed (with reason)
- `[HANDOFF:REQUEST]` - Persona wants to hand off
- `[HANDOFF:VALIDATED]` - Requirements checked and passed
- `[HANDOFF:COMPLETED]` - Next persona can begin
- `[SAFETY:LIMIT]` - Safety threshold exceeded
- `[PERSONA:STUCK]` - No progress detected

#### Monitoring Autonomous Progress

```bash
# View real-time journal activity
tail -f ~/workspace/JOURNAL.md

# Check overall status
journal-query.sh stats

# View pending work across all personas
journal-query.sh pending-work ALL

# Check current active persona
journal-query.sh current-persona
```

### Manual Persona Control

While the system is designed for autonomous operation, you can also manually control personas:

```bash
# Switch to a specific persona
/switch-persona developer

# Check work status
/work-status

# Execute prepared work
/execute-work

# View journal summary
/journal-summary
```

## 🔐 Git Configuration

Configure git credentials once on your host machine:

```bash
./configure-git-host.sh
```

This creates an isolated git configuration that's automatically injected into your containers, including:
- Git user name and email
- GitHub Personal Access Token
- GitHub CLI authentication

## 📁 Accessing Your Environment

### SSH Access

After deployment completes, the build script automatically sets up port forwarding:

```bash
# Connect to your development environment
ssh devuser@localhost -p 2222
# Password: devuser
```

### Web File Manager

Access the built-in Filebrowser at [http://localhost:8090](http://localhost:8090)
- Default credentials: admin/admin (change after first login!)
- Upload/download files through the web interface
- Edit files directly in the browser

## 🧩 Available Components

### Programming Languages
- **Python** - System, 3.11, or Miniconda versions
- **Java** - OpenJDK or Adoptium (11, 17, 21)
- **Go** - Versions 1.21 and 1.22
- **Rust** - Stable and nightly channels
- **Ruby** - System or 3.3
- **Scala** - 2.13 and 3.x
- **Kotlin** - Latest version

### Build Tools
- **Maven** - Java project management
- **Gradle** - Build automation
- **SBT** - Scala build tool

### AI Assistants
- **Claude Code** - Advanced AI coding assistant with:
  - Autonomous multi-persona development system
  - Event-sourced journal for persistent memory
  - Custom hooks for automation
  - End-to-end software creation capability

## 🎨 Theme Support

The TUI supports multiple themes to match your preference:

```bash
# Use built-in themes
AI_DEVKIT_THEME=matrix ./build-and-deploy.sh
AI_DEVKIT_THEME=ocean ./build-and-deploy.sh
AI_DEVKIT_THEME=neon ./build-and-deploy.sh
```

Available themes: `default`, `dark`, `matrix`, `ocean`, `minimal`, `neon`

## 🧹 Disk Management

### Colima Disk Cleanup

Colima uses a virtual machine with a fixed disk size. Over time, Docker images and containers can fill up this disk, causing deployment failures.

**The Problem**: When Colima's disk fills up, you'll see errors like:
- "No space left on device"
- Image pull failures
- Build failures

**The Solution**: The `cleanup-colima.sh` script helps reclaim disk space:

```bash
# Check what can be cleaned (dry run)
./cleanup-colima.sh --check

# Clean up disk space
./cleanup-colima.sh

# Force cleanup without prompts
./cleanup-colima.sh --force
```

**⚠️ CRITICAL WARNING**: 
- **DO NOT USE** the `--overlay2` option - it will corrupt Docker
- If you need to completely reset, delete and recreate the Colima VM:
  ```bash
  colima delete
  colima start --kubernetes --cpu 4 --memory 8 --disk 100
  ```

## 📚 Creating Custom Components

Components are self-contained YAML files that define how to install and configure tools. See [Creating Components](docs/components.md) for detailed instructions.

### Basic Component Structure

```yaml
id: MY_COMPONENT
name: My Component Name
version: "1.0.0"
group: component-group
requires: []
description: What this component does
installation:
  dockerfile: |
    # Installation commands
    RUN apt-get update && apt-get install -y my-tool
```

### Component Documentation (Optional)

Components can include markdown documentation that gets injected into LLM system prompts:

```markdown
# components/category/my-component.md

#### My Component Name

**Getting Started**:
```bash
# How to use this component
my-tool --help
```

## 🛠️ Advanced Features

### Nexus Repository Proxy

If you have a Nexus repository manager running locally, the build system automatically detects and configures package managers to use it:

```bash
# Start Nexus (optional)
docker run -d -p 8081:8081 --name nexus sonatype/nexus3

# Build will auto-detect and use Nexus for:
# - npm packages
# - Python packages (pip)
# - Maven artifacts
# - Go modules
# - APT packages
```

### Pre-build Scripts

Components can include pre-build scripts for complex setup:
- Generate configuration files
- Download additional resources
- Create documentation aggregates
- Set up component-specific structures

### Dependency Management

The build system includes:
- Topological sorting of components by dependencies
- Mutual exclusion groups (e.g., only one Python version)
- Automatic dependency validation
- Clear error messages for conflicts

## 🤝 Contributing

We welcome contributions! Please see our [Developer Guide](docs/developer.md) for information on:
- Setting up your development environment
- Creating feature branches
- Writing tests
- Submitting pull requests

For maintainers, see the [Maintainer Guide](docs/maintainer.md) for release procedures.

## 🐛 Troubleshooting

### Common Issues

1. **Permission Denied**: Make scripts executable with `chmod +x *.sh`
2. **Kubernetes Connection**: Ensure your cluster is running and `kubectl` is configured
3. **Build Failures**: Check `build-and-deploy.log` for detailed error messages
4. **Disk Space**: Use `cleanup-colima.sh` to free up space in Colima

See the [Troubleshooting Guide](docs/troubleshooting.md) for comprehensive solutions.

## 📋 System Requirements

### Minimum Requirements
- 4 CPU cores
- 8GB RAM
- 20GB disk space
- Kubernetes 1.20+

### Recommended
- 6+ CPU cores
- 12GB+ RAM
- 50GB+ disk space
- Fast internet connection for package downloads

## 💖 Support This Project

If you find AI DevKit Pod Configurator useful, please consider supporting its development:

☕ **[Buy me a coffee](https://buymeacoffee.com/ehausig)**

Your support helps maintain and improve this project. Thank you! 🙏

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This project builds upon excellent work from these organizations and projects:

### Core Technologies

- **[Claude Code](https://www.anthropic.com/claude-code)** by [Anthropic](https://www.anthropic.com) - AI coding assistant that lives in your terminal
  - Claude is a trademark of Anthropic PBC
  - [Documentation](https://docs.anthropic.com/en/docs/claude-code/overview) | [GitHub](https://github.com/anthropics/claude-code) | [npm](https://www.npmjs.com/package/@anthropic-ai/claude-code)
  
- **[Microsoft TUI Test](https://github.com/microsoft/tui-test)** - End-to-end terminal testing framework
  - Built and maintained by Microsoft
  - Provides rich API for testing terminal applications across platforms
  
- **[Ubuntu](https://ubuntu.com)** - The base operating system (22.04 LTS)
  - Copyright © Canonical Ltd.
  
- **[Kubernetes](https://kubernetes.io)** - Container orchestration platform
  - Originally designed by Google, now maintained by the Cloud Native Computing Foundation

### Development Tools

- **[Docker](https://www.docker.com)** - Container platform
- **[Colima](https://github.com/abiosoft/colima)** - Container runtime for macOS
- **[Git](https://git-scm.com)** - Version control system
- **[GitHub CLI](https://cli.github.com)** - GitHub's official command line tool
- **[Filebrowser](https://filebrowser.org)** - Web-based file management

### Languages and Runtimes

All programming language implementations retain their respective copyrights and licenses:
- Python, Node.js, Java (OpenJDK), Go, Rust, Ruby, and others

### Special Thanks

- The open source community for continuous improvements and contributions
- All beta testers who provided valuable feedback
- Contributors who help improve this project

---

Created with ❤️ by [Eric Hausig](https://github.com/ehausig)
