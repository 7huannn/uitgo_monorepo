# Security Documentation

## Overview

This document outlines the security measures implemented in the UITGo platform and provides guidance for maintaining security best practices.

## Security Measures Implemented

### 1. Secret Management

**DO NOT commit secrets to Git!**

- All secret files (`.tfvars`, `.tfstate`, `secrets.yaml`) are gitignored
- Use Sealed Secrets for Kubernetes secret management
- Use AWS Secrets Manager or HashiCorp Vault for production
- Environment variables for sensitive configuration

**Generating Secrets:**
```bash
# Generate strong passwords/keys
openssl rand -base64 32    # For JWT secrets
openssl rand -base64 24    # For passwords
```

### 2. Authentication & Authorization

#### API Authentication
- JWT-based authentication for all API endpoints
- Refresh token rotation for session management
- Role-based access control (RBAC) for authorization

#### Trip API Authorization
- Only trip owner (rider) can view/modify their trips
- Only assigned driver can update trip status
- Admin role has full access
- WebSocket connections require JWT authentication

#### WebSocket Security
- Proper origin validation (no wildcard `*`)
- JWT-only authentication (no query parameter spoofing)
- Trip access verification before connection upgrade

### 3. Admin Account Security

- No default/fallback admin credentials in production
- Admin seeding only allowed in development environment
- Minimum 12-character password requirement
- Explicit environment variable configuration required

### 4. Internal API Security

- Internal-only endpoints require `X-Internal-Token` header
- Empty secret = endpoints disabled (not bypassed)
- Constant-time comparison to prevent timing attacks

### 5. CORS Configuration

- No wildcard (`*`) origin with credentials
- Explicit origin whitelist required
- Security headers enabled (HSTS, X-Frame-Options, etc.)

### 6. Infrastructure Security

#### Kubernetes
- Network policies restrict pod-to-pod communication
- Pod security contexts (non-root, read-only filesystem)
- TLS for ingress traffic
- Secrets stored in Kubernetes Secrets (via Sealed Secrets)

#### Database (RDS)
- Encryption at rest enabled
- Automated backups with retention
- Multi-AZ deployment for production
- IAM database authentication option
- Restricted security group egress

#### Redis
- Password authentication required
- Non-root container execution
- Read-only root filesystem

### 7. CI/CD Security

- OIDC authentication for AWS (no static credentials)
- No sensitive data in PR comments
- Environment protection for production deployments
- Secrets managed via GitHub Secrets

## Security Checklist for Deployment

### Before First Deployment

- [ ] Generate all secrets using strong random values
- [ ] Configure AWS Secrets Manager or Vault
- [ ] Set up Sealed Secrets controller in cluster
- [ ] Create sealed secrets from templates
- [ ] Configure CORS allowed origins
- [ ] Set up TLS certificates (cert-manager recommended)
- [ ] Configure GitHub repository secrets
- [ ] Set up AWS OIDC provider for GitHub Actions

### Per-Environment Setup

- [ ] Create namespace-specific sealed secrets
- [ ] Configure environment-specific CORS origins
- [ ] Set up monitoring alerts for security events
- [ ] Enable audit logging
- [ ] Configure network policies

### Regular Security Maintenance

- [ ] Rotate JWT secrets quarterly
- [ ] Rotate database passwords
- [ ] Review and update dependencies
- [ ] Run security scanning (Trivy, Snyk)
- [ ] Review audit logs
- [ ] Update TLS certificates before expiry

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do NOT** open a public GitHub issue
2. Email security concerns to: [security@uitgo.com]
3. Include detailed description and reproduction steps
4. Allow reasonable time for fix before disclosure

## Security Scanning

The CI/CD pipeline includes:

- **Trivy**: Container image vulnerability scanning
- **golangci-lint**: Static code analysis for Go
- **terraform validate**: Infrastructure code validation

## Known Limitations

### Web Platform
- Browser storage (localStorage) is not secure against XSS
- Consider implementing BFF pattern for production web apps
- Use short-lived tokens with frequent rotation

### Development Environment
- Development uses weaker security for convenience
- Never use development settings in production
- Development secrets are example values only

## References

- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
