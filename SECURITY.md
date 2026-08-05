# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it **privately** to **stevie@skillfulgorilla.com**. Do not open a public GitHub issue.

Include detailed steps to reproduce the issue and allow reasonable time for a fix before public disclosure.

## Supported Versions

Only the `main` branch is supported with security updates.

## Security Checks

This project runs automated security analysis on every push:

- **Brakeman** — Static analysis for Rails security vulnerabilities
- **importmap audit** — Audits JavaScript dependencies

See `.github/workflows/ci.yml` for details.
