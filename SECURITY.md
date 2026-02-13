# Security Policy

## Supported Versions

We currently support the following versions of ILS with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue in ILS, please follow responsible disclosure practices.

### How to Report

**Preferred Method: GitHub Security Advisories**

1. Go to the [Security tab](../../security/advisories) of this repository
2. Click "Report a vulnerability"
3. Fill out the advisory form with details about the vulnerability

**Alternative: Email**

If you prefer not to use GitHub Security Advisories, you can email security reports to the maintainer.

### Please Do NOT:

- Open public GitHub issues for security vulnerabilities
- Disclose the vulnerability publicly before it has been addressed
- Exploit the vulnerability beyond what is necessary to demonstrate it

### What to Include

When reporting a vulnerability, please provide:

- **Description**: Clear explanation of the vulnerability
- **Impact**: What an attacker could potentially do
- **Steps to Reproduce**: Detailed steps to demonstrate the issue
- **Affected Versions**: Which versions of ILS are affected
- **Suggested Fix**: If you have ideas on how to fix it (optional)
- **Your Contact Info**: So we can follow up with questions

### Scope

This security policy covers:

- **iOS App**: Native iOS client application
- **macOS App**: Native macOS client application
- **Backend Server**: ILSBackend Swift server code
- **Dependencies**: Third-party libraries bundled with ILS

### Out of Scope

The following are typically not considered security vulnerabilities:

- Issues requiring physical access to an unlocked device
- Social engineering attacks
- Denial of service via rate limiting (expected behavior)
- Issues in third-party services ILS integrates with

## Response Timeline

- **Acknowledgment**: Within 48 hours of report
- **Initial Assessment**: Within 1 week
- **Fix Timeline**: Provided within 1 week of assessment
- **Public Disclosure**: After fix is released and users have time to update

## Security Best Practices

When using ILS, we recommend:

- Keep your app updated to the latest version
- Use strong authentication for backend servers
- Run backend servers in secure environments
- Review permissions requested by the app
- Report suspicious behavior immediately

## Questions?

For general security questions (not vulnerability reports), please open a discussion on GitHub.

Thank you for helping keep ILS and its users secure!
