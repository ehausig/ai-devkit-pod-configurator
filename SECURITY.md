# Security Policy

## Overview

The AI DevKit Pod Configurator team takes security seriously. This document outlines our security policies and procedures for reporting vulnerabilities.

## Staying Secure

For the best security posture, we strongly recommend:
- **Always use the latest release** - Security fixes and improvements are included in new versions
- **Monitor our releases** - Watch the repository or check our [releases page](https://github.com/ehausig/ai-devkit-pod-configurator/releases) regularly
- **Update promptly** - When a new version is released, especially if it contains security fixes

## Reporting a Vulnerability

If you discover a security vulnerability in AI DevKit Pod Configurator, please follow these steps:

### 1. Do NOT Create a Public Issue
Security vulnerabilities should never be reported through public GitHub issues, as this could put users at risk.

### 2. Report Privately
Please report security vulnerabilities by emailing:
- **Email**: [security@your-domain.com] *(Please update this with your actual security email)*
- **Subject Line**: `[SECURITY] AI DevKit Pod Configurator - Brief Description`

### 3. Include Essential Information
Your report should include:
- **Description**: Clear explanation of the vulnerability
- **Impact**: What could an attacker achieve by exploiting this?
- **Version Affected**: Which version did you find this in?
- **Steps to Reproduce**: Detailed instructions to trigger the vulnerability
- **Proof of Concept**: Code or commands that demonstrate the issue (if applicable)
- **Suggested Fix**: Your recommendations for addressing the vulnerability (optional)
- **Environment**: OS, Kubernetes version, and any relevant configuration

### 4. Responsible Disclosure
- Please give us reasonable time to address the issue before public disclosure
- We'll work with you to understand and validate the issue
- We'll keep you informed about our progress

## Our Commitment

When you report a security vulnerability, we commit to:

| Action | Timeline |
| ------ | -------- |
| Initial Response | Within 48 hours |
| Vulnerability Assessment | Within 5 business days |
| Fix Development | Varies by severity (see below) |
| Security Advisory | After fix is released |

### Severity Levels and Response Times

- **Critical**: Remote code execution, privilege escalation, data loss
  - Fix timeline: 1-3 days
- **High**: Authentication bypass, significant information disclosure
  - Fix timeline: 5-7 days
- **Medium**: Limited information disclosure, denial of service
  - Fix timeline: 14-30 days
- **Low**: Minor issues with minimal impact
  - Fix timeline: Next regular release

## Security Best Practices for Users

To maintain a secure deployment:

1. **Keep Updated**: Always use the latest version
2. **Secure Secrets**: 
   - Use Kubernetes secrets for sensitive data
   - Rotate SSH keys and credentials regularly
   - Never commit credentials to version control
3. **Network Security**:
   - Use network policies to restrict pod communication
   - Limit exposure of services (SSH, Filebrowser)
   - Use strong passwords for all services
4. **Container Security**:
   - Regularly rebuild with latest base images
   - Scan images for vulnerabilities
   - Run containers with minimal privileges

## Known Security Considerations

### SSH Access
- The pod runs an SSH server on port 2222
- Default password (`devuser`) should be changed immediately
- Consider using key-based authentication instead of passwords

### Filebrowser
- Default credentials (`admin`/`admin`) must be changed on first login
- Exposed on port 8090 - ensure proper network restrictions
- Review file access permissions

### AI Agent Integration
- Be cautious with permissions granted to AI agents
- Review Claude Code permissions in `claude-settings.json.template`
- The default configuration restricts access to system files and commands
- Regularly audit the permission lists for your use case

### Git Credentials
- Stored credentials are isolated to the container
- Use Personal Access Tokens with minimal required permissions
- Rotate tokens regularly
- Consider using short-lived tokens

## Security Release Process

When we fix a security vulnerability:
1. We'll release a new version with the fix
2. The release notes will clearly indicate security fixes (without details)
3. A security advisory will be published after the release
4. We'll credit the reporter (with permission)

## Security Contacts

- **Primary Contact**: [Your Name/Team]
- **Email**: [security@your-domain.com]
- **Response Time**: Within 48 hours

For general questions about security (not vulnerability reports), please use our [GitHub Discussions](https://github.com/ehausig/ai-devkit-pod-configurator/discussions).

## Acknowledgments

We appreciate the security research community's efforts in helping keep AI DevKit Pod Configurator secure. Contributors who report valid security issues will be acknowledged here (with permission).

### Security Researchers
- *Your name could be here!*

---

*Last updated: [Current Date]*
*Document version: 1.0*
