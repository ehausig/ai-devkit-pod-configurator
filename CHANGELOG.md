# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2025-11-01

This is a major release bringing comprehensive cross-platform container runtime support to the AI DevKit Pod Configurator. This release enables seamless use of Docker, nerdctl, and Podman across multiple Kubernetes distributions including K3s, Colima, Docker Desktop, minikube, and kind.

### Added

#### Cross-Platform Container Runtime Support
- **Configuration-first architecture** via `~/.ai-devkit/config.yaml` for explicit runtime configuration ([#47](https://github.com/ehausig/ai-devkit-pod-configurator/pull/47))
- Support for multiple container build tools: Docker, nerdctl, Podman
- Support for multiple Kubernetes distributions: K3s, Colima, Docker Desktop, minikube, kind, generic containerd
- Smart image loading strategies:
  - Direct build into K3s containerd (nerdctl only, fastest)
  - Save/load image transfer (Docker/Podman with K3s)
  - No import needed (Docker Desktop, minikube with Docker)
- Container runtime abstraction layer for unified command execution
- Proper socket path handling (K3s vs standard containerd)
- Namespace awareness (k8s.io vs default)

#### Pure Bash Template System
- Component-specific template functions eliminating Python dependency:
  - Python (`pip.conf`)
  - Node.js (`.npmrc`)
  - Rust (`cargo/config.toml`)
  - Maven (`settings.xml`)
  - Gradle (`init.gradle`)
  - SBT (`repositories`)
  - Ruby (`.gemrc`)
  - Go (environment variables)
- Faster execution with zero external dependencies
- Easier debugging and maintenance

#### Init Container Architecture
- Clean file distribution system using Kubernetes init containers
- Structured file staging during build with `file-mappings.yaml`
- Generated manifest with source/destination/permissions
- Proper ownership and permission handling
- Eliminated complex volume mount logic

#### Comprehensive Testing Framework
- 17 test sections with 35+ test cases across all components ([#47](https://github.com/ehausig/ai-devkit-pod-configurator/pull/47))
- Component-owned test suites including:
  - Installation verification
  - Version checking
  - Functionality testing
  - Package manager tests
  - Repository configuration tests
- Standardized test structure for all language and build tool components
- Test aggregation script: `~/.ai-devkit/tests/run-all.sh`

#### Repository Configuration System
- Vendor-agnostic artifact repository configuration
- Support for all package managers: PyPI, NPM, Maven, Gradle, SBT, Cargo, RubyGems, Go Proxy
- Authentication support (basic auth, tokens)
- Component-specific repository settings
- Build-time and runtime configuration application

#### New Components
- Node.js 20.x LTS with full configuration support
- Node.js 22.x with full configuration support
- AI Kanban component for autonomous development workflow tracking
- Comprehensive test suites for all existing components

#### Cross-Platform Cleanup
- Smart cleanup script (`scripts/cleanup-runtime.sh`) with runtime detection
- Runtime-specific operations:
  - Colima: VM disk cleanup, overlay2 orphan removal, journal cleanup
  - K3s: containerd cleanup with service management
  - Docker Desktop: System cleanup with UI integration
  - Generic: Universal container cleanup commands
- Safe mode and dry-run options
- System image protection

#### Documentation
- Comprehensive testing documentation (`docs/testing.md`)
- Component system documentation (`components/README.md`)
- LLM context documentation for AI assistants (`llm/`)
- Updated architecture documentation with new systems
- Cross-platform setup instructions in README

### Changed

#### Build System Enhancements
- Dynamic Dockerfile generation from component templates
- Pre-build script execution for complex setup
- Topological dependency resolution
- Permission aggregation from all components
- Enhanced error handling and validation
- Configuration reading using proper nested YAML keys

#### File Management
- ConfigMap-based file injection replacing direct mounts
- Structured staging directories for build context
- File mapping manifests for tracking
- Permission preservation across deployments
- Support for multiple file sources per component

#### Agent System Refactoring
- Migrated persona system from claude-code to ai-kanban component ([#45](https://github.com/ehausig/ai-devkit-pod-configurator/pull/45))
- Better separation of concerns between components
- Improved agent organization and documentation

#### Component Structure
- Moved component documentation to `components/README.md`
- Organized Claude Code files into dedicated subdirectory
- Restructured LLM context documentation
- Moved testing documentation to `docs/testing.md`
- Moved cleanup scripts to `scripts/` directory

### Fixed

- Pre-build scripts not executing correctly
- Syntax error in repository-loader
- Duplicate path references in ai-kanban and claude-code setup scripts
- nerdctl+k3s save-load import handling
- File handling for pre-build script outputs
- CONFIG_FILE preservation during component processing
- Component ID resolution for components with dots in names
- Config file availability during build process
- Repository configuration loading and application

### Removed

#### Cleanup and Technical Debt
- Eliminated 2,100+ lines of obsolete configuration scripts
- Removed Python-based template system and dependencies
- Removed VERSION file (now using git tags only)
- Removed CHANGELOG.md (restored in this release)
- Removed obsolete migration and diagnostic scripts
- Removed redundant cleanup-colima.sh script
- Removed unused config/repositories.yaml
- Removed obsolete migrate-config.sh script
- Removed docs/archive directory
- Removed prompts directory
- Removed obsolete documentation files:
  - `docs/components.md`
  - `docs/developer.md`
  - `docs/maintainer.md`
  - `docs/roadmap.md`
  - `docs/troubleshooting.md`
- Removed premature release infrastructure
- Removed Nexus-specific configuration files

### Breaking Changes

- **Configuration Required**: New installations now require manual creation of `~/.ai-devkit/config.yaml`
- **Removed configure-ai-devkit.sh**: Users must manually configure container runtime settings
- **Agent Persona Migration**: Agent personas moved from claude-code to ai-kanban component
- **Repository Configuration**: Nexus auto-detection removed in favor of explicit configuration

### Migration Guide

For existing users upgrading from v0.3.0:

1. Create `~/.ai-devkit/config.yaml`:
```yaml
container:
  build_tool: docker       # or nerdctl, podman
  runtime: colima          # or k3s, docker-desktop, minikube, kind
  runtime_import: none     # or direct (nerdctl+k3s), save-load (docker+k3s)
```

2. Update your workflow:
   - Remove references to `configure-ai-devkit.sh` (no longer exists)
   - Configure runtime explicitly instead of relying on auto-detection
   - Update any custom scripts that depend on old configuration structure

3. Review new features:
   - Check out comprehensive test suites in `~/.ai-devkit/tests/`
   - Explore new cleanup script: `scripts/cleanup-runtime.sh`
   - Review updated documentation in `docs/` and `components/`

### Statistics

- **Commits**: 387 since v0.3.0
- **Files Changed**: 237 in PR #47
- **Additions**: +19,406 lines
- **Deletions**: -4,267 lines
- **Net Change**: +15,139 lines
- **Components Updated**: 30+ (all languages and build tools)
- **Test Suites Added**: 30+ component test suites
- **Documentation Files**: 60+ markdown files updated/created

### Contributors

- @ai-agent-eric - Cross-platform support implementation, testing framework, documentation
- @ehausig - Project maintenance, code review, repository management

### Acknowledgments

This release was driven by real-world usage feedback and the need to support diverse development environments across macOS and Linux with different container runtime preferences. Special thanks to all beta testers and contributors who provided valuable feedback during development.

---

## [0.3.0] - 2025-06-27

### Added
- Claude Code hooks system for deterministic behavior control
- Slash command support with journal command
- Recipe management system test

### Changed
- Reorganized Claude Code files into dedicated subdirectory
- Updated hook script extraction in build process

### Fixed
- Claude Code hooks handling actual JSON response structure
- Hook script extraction issue in build process

---

## [0.1.2] - 2025-06-25

### Added
- Community files for open source readiness (CODE_OF_CONDUCT.md, CONTRIBUTING.md, SECURITY.md)
- Comprehensive developer workflow guide

### Changed
- Streamlined release process with automated version bumping
- Enhanced build flow clarity and responsiveness

---

## [0.1.0] - 2025-06-25

Initial release of AI DevKit Pod Configurator

### Added
- Terminal User Interface (TUI) for component selection
- Component-based architecture
- Support for multiple programming languages (Python, Java, Go, Rust, Ruby, Scala, Kotlin)
- Build tools integration (Maven, Gradle, SBT)
- Claude Code AI assistant integration
- Kubernetes deployment automation
- Persistent storage support
- SSH server and Filebrowser web UI
- Theme support for TUI
- Basic testing framework

---

[Unreleased]: https://github.com/ehausig/ai-devkit-pod-configurator/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/ehausig/ai-devkit-pod-configurator/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ehausig/ai-devkit-pod-configurator/compare/v0.1.2...v0.3.0
[0.1.2]: https://github.com/ehausig/ai-devkit-pod-configurator/compare/v0.1.0...v0.1.2
[0.1.0]: https://github.com/ehausig/ai-devkit-pod-configurator/releases/tag/v0.1.0
