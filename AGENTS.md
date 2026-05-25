# Decompress — AGENTS.md

## Quick start

```bash
make build          # swift build (debug)
make build-strict   # swift build -Xswiftc -strict-concurrency=complete
make test           # swift test --verbose (requires Xcode.app)
make test-coverage  # swift test --enable-code-coverage + llvm-cov report
make format         # xcrun swift-format format --in-place Sources/ Tests/
make format-check   # xcrun swift-format lint --recursive Sources/ Tests/
make release        # swift build -c release
make run            # build + bundle + open .app
make clean          # swift package clean && rm -rf .build
make session        # start new dev session: make session <branch-name>
make check          # full CI gate: format + format-check + strict build + coverage
```

All commands are in `Makefile`. CI pipeline in `.github/workflows/ci.yml`.

## Project structure

SPM-only (no `.xcodeproj`). Swift 6 language mode (`swift-tools-version: 6.0` in `Package.swift`). macOS 15+ only. No external dependencies.

```
Sources/Decompress/
├── App/DecompressApp.swift              # @main entry, window/scene config
├── Models/ArchiveFormat.swift           # Format enum + magic bytes
├── Models/ExtractionResult.swift        # Result models + ExtractionState
├── Services/ArchiveFormatDetector.swift # Static format detection + ZIP encryption check
├── Services/DecompressionService.swift  # Actor (shared singleton)
├── Services/FileManager+Extensions.swift
├── Services/ServiceError.swift          # Error types for extraction
├── ViewModels/DecompressViewModel.swift # @Observable, @MainActor
└── Views/
    ├── ContentView.swift                # Root: switches views by extractionState
    ├── DragDropView.swift               # Drop zone + file picker + controls
    ├── ExtractionCompletedView.swift    # Success results display
    ├── ExtractionFailedView.swift       # Error display + retry
    ├── ExtractionProgressView.swift     # Progress bar during extraction
    ├── FileRowView.swift                # Single file row in selected list
    ├── HelpView.swift                   # Help window (usage, formats, tips)
    ├── PasswordPromptView.swift         # Password toggle + SecureField
    └── SettingsView.swift               # Settings window (General, Formats tabs)
Tests/
├── DecompressTests/                     # XCTest unit tests
└── DecompressUITests/                   # UI tests
```

## Architecture

- **MVVM**: Views consume `@Environment(DecompressViewModel.self)`. ViewModel is `@Observable` + `@MainActor`.
- **DecompressionService** is an `actor` with a `shared` singleton. Wraps system tools (`/usr/bin/ditto`, `/usr/bin/tar`, `/usr/bin/gunzip`, `/usr/bin/bunzip2`, `/usr/bin/unxz`, `/usr/bin/unar`, `/usr/bin/unzip`) via `Process` + `withCheckedThrowingContinuation`.
- **Format detection**: file extension first (longest match wins), then magic bytes as fallback.
- **Testing**: XCTest — requires full Xcode (`xcode-select` pointed at Xcode.app), not just Command Line Tools.
- **Password support**: ZIP encrypted archives use `/usr/bin/unzip -P`, 7Z/RAR use `/usr/bin/unar -p`.

## Conventions

- **No comments** in source code (existing code has none).
- **swift-format** — formatting enforced via `xcrun swift-format` in CI and via `make format` / `make format-check` locally. Requires Xcode.app (`xcode-select` pointed at it). The Xcode-bundled version is used so CI and local tools match exactly.
- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/) (e.g. `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`, `ci:`).
- **Pre-commit hook** runs `xcrun swift-format format --in-place`, then `xcrun swift-format lint`, then `swift build -Xswiftc -strict-concurrency=complete`. Enable: `git config core.hooksPath .githooks`. Skip: `git commit --no-verify`.
- **Pre-push hook** runs `swift test --verbose`. Enable with the same `core.hooksPath` setting. Skip: `git push --no-verify`.
- **Strict concurrency** — every build includes `-Xswiftc -strict-concurrency=complete` to catch data-race safety issues (`Sendable`, `@MainActor` violations) at compile time.
- **Code coverage** — `swift test --enable-code-coverage` generates an `llvm-cov` report. Run via `make test-coverage`.
- All models and result types conform to `Sendable`. Actor methods are `async`.
- **No inline private views** — every view struct gets its own file.
- **Accessibility**: Every interactive element gets `.accessibilityLabel()`. Decorative images get `.accessibilityHidden(true)`. Grouped elements use `.accessibilityElement(children: .combine)`.
- **Keyboard shortcuts**: Primary actions (Open, Extract, Clear, Reveal) get keyboard shortcuts. Avoid system conflicts.

## macOS Human Interface Guidelines

- **Window sizing**: `.windowResizability(.contentMinSize)` + `.frame(minWidth:minHeight:)`.
- **Window style**: `.windowStyle(.titleBarAndToolbar)`.
- **Spacing**: 20pt padding on top-level views. VStack/HStack spacing: 16–20pt (sections), 8pt (related controls), 4pt (tight text).
- **Toolbar**: Secondary actions only (Clear, Help). Primary actions go in the content area.
- **Buttons**: `.borderedProminent` for primary, `.bordered` for secondary. `.controlSize(.large)` on primary.
- **Settings**: TabView + Form + Section. Min frame 480x300.
- **Drop zone**: Dashed border (`StrokeStyle(dash: [8])`), accent color on hover.
- **Passwords**: Use SecureField with `.textFieldStyle(.roundedBorder)`.

## View patterns

- One top-level view per file, matching the filename.
- Shared ViewModel via `@Environment(DecompressViewModel.self)`.
- Two-way bindings via `Bindable(viewModel)`.
- State that is only relevant to a single view stays as `@State` in that view (e.g. `detectedFormats`, `isTargeted`).
- `extractAll()` captures all needed values upfront to avoid actor isolation issues.

## CI

Single job: `make format-check` -> `make build-strict` -> `swift test --enable-code-coverage` + `llvm-cov report` on `macos-15`. Release job also runs `scripts/make-app-bundle.sh` to produce `Decompress.app`.

## App bundle

`scripts/make-app-bundle.sh <binary>` wraps an SPM binary into `Decompress.app/Contents/MacOS/` with `Info.plist` from `support/Info.plist` (or auto-generated fallback). Used only in CI release job.

## Gotchas

- `detectFormat(from:)` is `nonisolated` — can be called from any context.
- Adding a new archive format: add case to `ArchiveFormat`, add magic bytes + extensions, add extraction path in `DecompressionService.extract()`, add XCTest cases.
- Tests are lightweight (format detection, no real archive files in repo). Integration tests require actual archives.
- **`autoExtractToSourceDir`** (Settings toggle) and **`extractInPlace`** (per-session toggle) are separate concerns: settings controls the default behavior, per-session toggle overrides it. Both are captured at extraction time in `extractAll()` to avoid actor isolation issues.
- **`swift-format`** is required for `make format` / `make format-check`. It uses `xcrun swift-format` (Xcode-bundled) so CI and local are identical and no extra install is needed.
- **Coverage report** requires running `make test-coverage` after a successful build; the profdata file is generated by the test run.
- **Pre-push hook** runs the full test suite, which can be slow. Push with `--no-verify` to skip when needed.
