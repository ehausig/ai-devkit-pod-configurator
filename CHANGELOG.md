# Changelog

All notable changes to AI DevKit Pod Configurator will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Command permissions system for Claude Code integration
- Dynamic permission aggregation from all selected components
- Team Topologies-based agent system for Claude Code
- Requirements analyst agent for interactive project setup
- Solution architect, cloud architect, and data architect agents
- `/create-prompt` command for guided requirements gathering
- Pre-build script capability for complex component setup
- Component documentation import system with `@import` syntax
- Animated deployment status indicators

### Changed
- Refactored build system to use `yq` and `jq` instead of sed/awk
- Extracted Node.js from base image to component system
- Improved error handling and validation throughout
- Enhanced Claude Code configuration with dynamic settings
- Updated documentation to reflect current system state

### Fixed
- Critical bug where customized Dockerfile was overwritten during build
- Component inject_files not being processed correctly
- Missing files in container due to build process error

### Security
- Improved command permission validation
- Better secret management for git credentials

## [1.0.0] - 2024-01-15

### Added
- Initial release of AI DevKit Pod Configurator
- Beautiful Terminal User Interface (TUI) with 6 themes
- Component-based architecture for languages and tools
- Support for Python, Node.js, Java, Go, Rust, Ruby, Scala, Kotlin
- Build tools: Maven, Gradle, SBT
- Claude Code AI assistant integration
- Microsoft TUI Test for terminal testing
- Git configuration management
- Filebrowser web interface
- SSH access to development environment
- Kubernetes deployment with persistent storage
- Nexus repository proxy auto-detection
- Colima disk cleanup utility

### Features
- Interactive component selection with dependencies
- Real-time build and deployment status
- Theme customization system
- Comprehensive documentation
- Platform support for macOS with Colima

[Unreleased]: https://github.com/ehausig/ai-devkit-pod-configurator/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ehausig/ai-devkit-pod-configurator/releases/tag/v1.0.0
