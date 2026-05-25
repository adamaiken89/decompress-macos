# Decompress — AGENTS.md

## Quick start

```bash
make build      # swift build (debug)
make test       # swift test --verbose (requires Xcode.app)
make lint       # swiftlint --strict (warnings → errors)
make lint-fix   # swiftlint --fix
make release    # swift build -c release
make run        # swift run
make clean      # swift package clean && rm -rf .build
```

All commands are in `Makefile`. CI pipeline in `.github/workflows/ci.yml`.

## Project structure

SPM-only (no `.xcodeproj`). Swift 6 language mode (`swift-tools-version: 6.0` in `Package.swift`). macOS 15+ only. No external dependencies.

```
Sources/Decompress/
├── App/DecompressApp.swift              # @main entry, window/scene config
├── Models/ArchiveFormat.swift           # Format enum + magic bytes
├── Models/ExtractionResult.swift        # Result models + ExtractionState
├── Services/DecompressionService.swift  # Actor (shared singleton)
├── Services/FileManager+Extensions.swift
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
- **SwiftLint strict mode** — `.swiftlint.yml` disables `trailing_whitespace` and `line_length`; all other rules are enforced.
- **Pre-commit hook** runs `swiftlint --strict` then `swift build`. Enable: `git config core.hooksPath .githooks`. Skip: `git commit --no-verify`.
- **No force unwrapping** — `force_unwrapping` is an opt-in error.
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

Single job: `swiftlint --strict` -> `swift build` -> `swift test` on `macos-15`. Release job also runs `scripts/make-app-bundle.sh` to produce `Decompress.app`.

## App bundle

`scripts/make-app-bundle.sh <binary>` wraps an SPM binary into `Decompress.app/Contents/MacOS/` with `Info.plist` from `support/Info.plist` (or auto-generated fallback). Used only in CI release job.

## Gotchas

- `detectFormat(from:)` is `nonisolated` — can be called from any context.
- Adding a new archive format: add case to `ArchiveFormat`, add magic bytes + extensions, add extraction path in `DecompressionService.extract()`, add XCTest cases.
- Tests are lightweight (format detection, no real archive files in repo). Integration tests require actual archives.
- **`autoExtractToSourceDir`** (Settings toggle) and **`extractInPlace`** (per-session toggle) are separate concerns: settings controls the default behavior, per-session toggle overrides it. Both are captured at extraction time in `extractAll()` to avoid actor isolation issues.
