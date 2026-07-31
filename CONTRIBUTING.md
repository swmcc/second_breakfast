# Contributing to Second Breakfast

Thanks for your interest in contributing to Second Breakfast!

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Run `make local.setup` to set up your development environment
4. Create a feature branch: `git checkout -b feature/your-feature`

## Development Workflow

### Running the App

```bash
make local.run
```

### Running Tests

```bash
make local.test
```

### Linting

```bash
make lint        # Check for issues
make lint.fix    # Auto-fix issues
```

### Security Scan

```bash
make local.brakeman
```

## Pull Request Process

1. Ensure all tests pass: `make local.test`
2. Ensure linting passes: `make lint`
3. Ensure security scan passes: `make local.brakeman`
4. Update documentation if needed
5. Create a pull request with a clear description

## Code Style

- Follow Ruby community style guidelines (enforced by RuboCop)
- Write meaningful commit messages
- Keep commits focused and atomic
- Add tests for new functionality

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include steps to reproduce for bugs
- Check existing issues before creating a new one
