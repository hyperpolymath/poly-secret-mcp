# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Security Measures

This project implements the following security controls:

### Cryptography
- **No MD5/SHA1** for security purposes (CI enforced)
- SHA256+ required for all cryptographic operations
- Secrets are never logged or stored in plaintext

### Network Security
- **HTTPS only** - HTTP URLs blocked except localhost (CI enforced)
- No hardcoded secrets in source code (CI enforced via trufflehog)

### Container Security
- Non-root container user (`mcp`, UID 1000)
- Minimal base image (Chainguard Wolfi)
- No secrets baked into images

### Supply Chain Security
- Dependency lockfiles (deno.lock)
- Automated dependency updates (Dependabot)
- CodeQL security scanning
- OpenSSF Scorecard assessment
- Sigstore provenance attestation ready

### Secrets Management
- All secrets handled via external secret managers (Vault, SOPS)
- Environment variables for configuration (not hardcoded)
- Token lifecycle management delegated to secret backends

## Reporting a Vulnerability

**DO NOT** report security vulnerabilities through public GitHub issues.

Instead, please report them via:

1. **GitHub Security Advisories**: [Report a vulnerability](https://github.com/hyperpolymath/poly-secret-mcp/security/advisories/new)
2. **Email**: security@hyperpolymath.dev (if available)

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact assessment
- Any suggested mitigations

### Response Timeline
- **Initial Response**: Within 48 hours
- **Triage & Assessment**: Within 7 days
- **Fix Development**: Depends on severity
  - Critical: 24-72 hours
  - High: 1-2 weeks
  - Medium/Low: Next release cycle

### Disclosure Policy
We follow coordinated disclosure:
- 90-day disclosure deadline
- Public disclosure after fix is released
- Credit given to reporters (unless anonymity requested)

## Security Best Practices for Users

1. **Never commit Vault tokens** or SOPS keys to version control
2. **Use environment variables** for `VAULT_ADDR` and `VAULT_TOKEN`
3. **Rotate secrets regularly** using the provided tools
4. **Review audit logs** in your secret manager
5. **Use TLS/mTLS** for Vault connections in production
