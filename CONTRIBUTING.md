# Contributing to Decompress

Thank you for your interest in contributing to Decompress!

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a feature branch: `git checkout -b feat/your-feature`
4. Make your changes
5. Run tests: `make test`
6. Commit your changes (see commit conventions below)
7. Push to your fork and submit a Pull Request

## Development Setup

### Prerequisites

- macOS 15 (Sequoia) or later
- Xcode 16+ (for swift-format and XCTest)
- Homebrew (for `unar` if testing 7Z/RAR formats)

### Build & Test

```bash
make build          # Debug build
make build-strict   # Strict concurrency check
make test           # Run all tests
make test-coverage  # Run tests with coverage
```

### Code Quality

```bash
make format         # Auto-format code
make format-check   # Lint code
make check          # Full CI gate (format-check → build-strict → test-coverage)
```

## Code Style

- **2-space indentation** (not tabs, not 4-space)
- **No comments** in source code
- Use `loc("key")` for all user-facing strings
- Use `DesignConstants` for spacing/font/padding/layout values
- Use `AppColors` for all colors (no system colors directly)
- Use button modifiers: `.primaryButton()`, `.secondaryButton()`, `.inlineButton()`
- Use background modifiers: `.sectionBackground()`, `.cardBackground()`, `.rowBackground()`

## Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature
- `fix:` — bug fix
- `refactor:` — code change that neither fixes a bug nor adds a feature
- `test:` — adding missing tests
- `chore:` — maintenance tasks

Example: `feat: add support for ISO format`

## Pre-commit Hooks

Enable hooks for automatic formatting and linting:

```bash
git config core.hooksPath .githooks
```

The pre-commit hook will:
1. Auto-format your code with swift-format
2. Lint with swift-format
3. Build with strict concurrency checks

Skip with `--no-verify` if needed.

## Pull Request Guidelines

1. Keep PRs focused on a single change
2. Include a clear description of what changed and why
3. Make sure all tests pass
4. Update documentation if needed
5. Follow existing code style and patterns

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include steps to reproduce for bugs
- Specify macOS version and Xcode version
- Attach relevant logs if applicable

## License

By contributing, you agree that your contributions will be licensed under the MIT License.