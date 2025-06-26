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

### For Contributors
- **[Developer Guide](docs/developer.md)** - Contributing code and creating pull requests
- **[Maintainer Guide](docs/maintainer.md)** - Release management and repository maintenance

## 🎯 Overview

AI DevKit Pod Configurator provides a beautiful TUI (Terminal User Interface) for selecting and deploying customized development environments in Kubernetes. Each environment is built from a minimal Ubuntu base with only the components you need.

### Key Features

- 🎨 **Beautiful TUI** - Interactive component selection with theme support
- 🧩 **Modular Architecture** - Add only what you need: languages, tools, AI assistants
- 🤖 **AI Assistant Support** - Optional Claude Code integration
- 🔧 **Language Support** - Python, Java, Go, Rust, Ruby, Scala, Kotlin, and more
- 📦 **Build Tools** - Maven, Gradle, SBT with optional Nexus proxy support
- 🧪 **TUI Testing** - Microsoft TUI Test pre-installed for testing terminal apps
- 💾 **Persistent Storage** - Your code and configuration persist across restarts
- 🌐 **Web File Manager** - Built-in Filebrowser for easy file management
- 🔒 **Secure** - Runs as non-root user with proper isolation

## 📸 Screenshots

### Component Selection Interface
![Component Selection Interface](docs/images/component-selection.png)
*Interactive TUI for selecting development tools and languages*

### Deployment Status Dashboard
![Deployment Status Dashboard](docs/images/deployment-status.png)
*Real-time deployment progress with animated status indicators*

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

## 🔐 Git Configuration

Configure git credentials once on your host machine:

```bash
./configure-git-host.sh
```

This creates an isolated git configuration that's automatically injected into your containers, including:
- Git user name and email
- GitHub Personal Access Token
- GitHub CLI authentication

## 📁 File Management

Access the web-based file manager:

```bash
./access-filebrowser.sh
# Or manually:
kubectl port-forward -n ai-devkit service/ai-devkit 8090:8090
```

Navigate to [http://localhost:8090](http://localhost:8090)
- Default credentials: admin/admin (change after first login!)

## 🧹 Maintenance

### Disk Cleanup (Colima users)

```bash
# Clean up disk space in Colima
./cleanup-colima.sh

# Check what can be cleaned
./cleanup-colima.sh --check

# Force cleanup without prompts
./cleanup-colima.sh --force
```

## 🔧 Optional: Nexus Repository Manager

If you have a local Nexus repository manager, the build script will automatically detect and use it for faster builds:

```bash
# Start Nexus (if not already running)
docker run -d -p 8081:8081 --name nexus sonatype/nexus3

# The build script will automatically detect Nexus on port 8081
./build-and-deploy.sh
```

## 🏗️ Architecture

The project uses a plugin-style architecture where each component is self-contained. For details, see the [Architecture documentation](docs/architecture.md).

## 🛠️ Available Components

### Programming Languages
- **Python**: System (3.10), Official 3.11, Miniconda
- **Java**: OpenJDK 11/17/21, Eclipse Adoptium 11/17/21
- **Go**: 1.21, 1.22
- **Rust**: Stable, Nightly channels
- **Ruby**: System package, 3.3 via rbenv
- **Scala**: 2.13, 3.x
- **Kotlin**: Latest version

### Build Tools
- **Maven** - Java build automation
- **Gradle** - Modern build tool for JVM
- **SBT** - Scala build tool

### AI Assistants
- **Claude Code** - Anthropic's AI coding assistant (requires subscription)

## 🤝 Contributing

We welcome contributions! Please see our [Developer Guide](docs/developer.md) for information on:
- Setting up your development environment
- Creating feature branches
- Writing tests
- Submitting pull requests

For maintainers, see the [Maintainer Guide](docs/maintainer.md) for release procedures.

## 🚀 Roadmap

### Version 1.0 (Coming Soon)
- [ ] Semantic versioning implementation
- [ ] Stable API for component definitions
- [ ] Comprehensive test suite

See [ROADMAP.md](docs/roadmap.md) for future plans.

## ⚠️ Known Issues

See the [Troubleshooting Guide](docs/troubleshooting.md) for known issues and workarounds.

## 💖 Support This Project

If you find AI DevKit Pod Configurator useful, please consider supporting its development:

☕ **[Buy me a coffee](https://buymeacoffee.com/ehausig)**

Your support helps maintain and improve this project. Thank you! 🙏

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

See [ACKNOWLEDGMENTS.md](docs/acknowledgments.md) for credits to the projects and teams that made this possible.

---

Created with ❤️ by [Eric Hausig](https://github.com/ehausig)
