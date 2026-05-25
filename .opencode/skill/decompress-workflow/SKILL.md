---
name: decompress-workflow
description: Use when working on decompress-macos — building, testing, linting, or debugging the SwiftUI decompression app. NOT for general Swift questions outside this project.
---

# Decompress macOS — Development Workflow

This skill covers the common development tasks for the decompress-macos project.

## Build

```bash
make build      # debug build
make release    # release build
make run        # run the app
```

## Test

```bash
make test       # swift test (requires Xcode)
```

Tests use XCTest. The main test files are:
- `Tests/DecompressTests/ArchiveFormatTests.swift`
- `Tests/DecompressTests/DecompressionServiceTests.swift`

## Lint

```bash
make lint       # swiftlint --strict
```

All violations must be fixed before committing. The `--strict` flag promotes all warnings to errors.

## CI pipeline

The `.github/workflows/ci.yml` runs three jobs:
1. **lint** — `swiftlint --strict`
2. **test** — `swift test` (on macos-15 with Xcode)
3. **build** — `swift build -c release` (depends on lint + test)

## Pre-commit hook

A pre-commit hook at `.githooks/pre-commit` runs lint + build before each commit.
Enable it with:

```bash
git config core.hooksPath .githooks
```

## Adding a new archive format

1. Add a new case to `ArchiveFormat` in `Sources/Decompress/Models/ArchiveFormat.swift`
2. Add display name, file extensions, and magic bytes
3. Add extraction logic in `DecompressionService`
4. Add tests in `Tests/DecompressTests/`
5. Run `make lint` and `make test`

## Debugging extraction failures

1. Check the error message in the UI — the service provides localized errors
2. Verify the system tool exists: `which ditto tar gunzip bunzip2 unxz unar`
3. Test manually: run the equivalent command in terminal
4. Check the `.build/` cache if the issue is build-related
