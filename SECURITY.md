# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email the maintainer directly or use GitHub's private vulnerability reporting
3. Include detailed steps to reproduce the issue
4. Allow reasonable time for a fix before public disclosure

## Security Measures

This project implements:

- **Brakeman** - Static analysis for Rails security vulnerabilities
- **Strong Parameters** - Protection against mass assignment
- **CSRF Protection** - Cross-site request forgery prevention
- **SQL Injection Prevention** - Parameterized queries via ActiveRecord
- **API Authentication** - Bearer token authentication for write operations

## Running Security Checks

```bash
make local.brakeman
```

## Supported Versions

Only the latest version receives security updates.
