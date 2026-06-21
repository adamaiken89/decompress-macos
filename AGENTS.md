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
make session        # make session <branch-name> (runs scripts/start-session.sh)
make check          # format → format-check → build-strict → test-coverage
make version        # read version from support/Info.plist
make bump-version V=x.y.z  # update support/Info.plist version
```

CI pipeline in `.github/workflows/ci.yml`. Runs on `macos-15`.

## Project structure

SPM-only (no `.xcodeproj`). Swift 6, macOS 15+, no external dependencies.

```
Sources/Decompress/
├── App/DecompressApp.swift
├── Helpers/
│   ├── AppVersion.swift          # Read version from Info.plist
│   ├── ButtonStyles.swift        # .primaryButton() / .secondaryButton() / .inlineButton()
│   ├── Colors.swift              # AppColors constants
│   ├── DesignConstants.swift     # Font, spacing, padding constants
│   ├── Loc.swift                 # loc("key") → NSLocalizedString wrapper
│   ├── View+Backgrounds.swift    # .sectionBackground() / .cardBackground() / .rowBackground()
│   └── VisualEffectBackground.swift
├── Models/
│   ├── ArchiveEntry.swift        # ArchiveEntry + ArchiveContent (Sendable)
│   └── ArchiveFormat.swift       # 11 formats, magic bytes, extensions
├── Services/
│   ├── ArchiveFormatDetector.swift
│   ├── DecompressionService.swift           # Actor (shared singleton)
│   ├── DecompressionService+ContentListing.swift  # listContents() per format
│   ├── DecompressionService+ProcessRunner.swift   # runProcess() + runProcess(forOutput:)
│   ├── FileManager+Extensions.swift
│   └── ServiceError.swift
├── ViewModels/
│   └── DecompressViewModel.swift  # @Observable @MainActor, shared singleton
├── Views/
│   ├── ArchiveContentView.swift   # Archive content browsing with per-file selection
│   ├── ContentView.swift          # Root: switches by extractionState (lite vs full)
│   ├── DragDropView.swift
│   ├── ExtractionCompletedView.swift
│   ├── ExtractionFailedView.swift
│   ├── ExtractionProgressView.swift
│   ├── FileRowView.swift
│   ├── HelpView.swift
│   ├── LiteContentView.swift      # Minimal UI for file-open launches
│   ├── PasswordPromptView.swift
│   └── SettingsView.swift
└── Resources/
Tests/
├── DecompressTests/               # XCTest (unit)
└── DecompressUITests/             # Dead code — target not in Package.swift
```

## Architecture

- **MVVM**: Views via `@Environment(DecompressViewModel.self)`. ViewModel `@Observable` + `@MainActor`, `shared` singleton.
- **DecompressionService**: `actor` with `shared` singleton. Wraps system tools via `Process` + `withCheckedThrowingContinuation`. Two `runProcess` variants: one with progress callback, one returns stdout string.
- **Format detection**: extension first (longest suffix wins), magic bytes fallback. `detectFormat(from:)` + `isZipEncrypted(_:)` are `nonisolated`.
- **Extraction state machine**: `idle` → `browsing` / `preparing` → `extracting` → `completed` / `failed`. `cancelExtraction()` returns to `idle`.
- **Archive browsing** (`browsing` state): `previewArchives()` lists contents, `ArchiveContentView` shows per-file checkboxes, `extractAll(selectedEntries:)` supports selective extraction.

## Conventions

- **No comments** in source code.
- **2-space indentation** (not tabs, not 4-space).
- **`loc("key")`** for all user-facing strings (wraps `NSLocalizedString`).
- **`DesignConstants`** for all spacing/font/padding/layout values — do not hardcode. Includes `Spacing`, `Padding`, `FontSize`, and `Layout` (frame widths, spinner scale).
- **`AppColors`** for all colors — do not use system colors directly.
- **Button style modifiers**: `.primaryButton()`, `.secondaryButton()`, `.inlineButton()`.
- **Background modifiers**: `.sectionBackground()`, `.cardBackground()`, `.rowBackground()`.
- **Commands**: Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`).
- **Pre-commit hook**: `swift-format format --in-place` → `swift-format lint` → `swift build -Xswiftc -strict-concurrency=complete`. Enable: `git config core.hooksPath .githooks`. Skip: `--no-verify`.
- **Pre-push hook**: `swift test --verbose`. Same hooksPath.
- **No SwiftLint** in Makefile or CI (despite `.opencode/opencode.json` referencing it). Only `swift-format` enforced.
- **Strict concurrency**: every build includes `-Xswiftc -strict-concurrency=complete`.

## Tool search order

`DecompressionService.findTool(_:)` checks:
1. `/opt/homebrew/bin/<name>` (Apple Silicon Homebrew)
2. `/usr/local/bin/<name>` (Intel Homebrew)
3. `/usr/bin/<name>` (system)

`unar` / `lsar` must be installed via Homebrew — not bundled. System tools (`tar`, `gunzip`, `bunzip2`, `unxz`, `ditto`, `unzip`) live in `/usr/bin`.

## Extraction paths by format

| Format | Tool | Notes |
|--------|------|-------|
| ZIP | `ditto -x -k` (plain), `unzip -P` (password), `unzip` (selected entries) | Encryption detection via bit flag |
| TAR / TAR.GZ / TAR.BZ2 / TAR.XZ | `tar -x[f|zf|jf|Jf]` | |
| GZIP | `gunzip -f` | |
| BZIP2 | `bunzip2 -f` | |
| XZ | `unxz -f` | |
| 7Z / RAR / SPLIT | `unar -o` (+ `-p` for password, `-i` for selected entries) | Requires Homebrew `unar` |

## Gotchas

- `extractAll()` captures all values upfront (`useExtractInPlace`, `useAutoDir`, `useOutputDir`, `usePassword`, `shouldTrash`, `useSelectedEntries`) to avoid actor isolation issues.
- `autoExtractToSourceDir` (settings persisted) vs `extractInPlace` (per-session toggle) are separate. `extractInPlace` overrides `autoExtractToSourceDir`.
- `ArchiveContentView` is shown in `browsing` state — user can select individual files before extraction.
- UI tests target exists on disk but is NOT in `Package.swift` — dead code.
- `make check` runs `format` (which modifies files) then `format-check` (which lints). If format changes files, format-check may fail. Run `make format` first then `make check` separately if needed.
- Coverage report: `make test-coverage` after a full build. Profdata at `.build/debug/codecov/default.profdata`.
- Integration tests require real archive files (none committed to repo).
- `DetectFormatUITests` in CI triggers the menu bar UI test — may fail if accessibility permissions not granted.
- **Lite UI on file-open**: When `launchedByFileOpen = true`, `ContentView` shows `LiteContentView` instead of full UI. Lite mode: password prompt (if encrypted), progress bar during extraction, auto-quit on success, minimal error view on failure. No toolbar, no drag-drop, no file list, no archive browsing, no extraction-completed detail view. `LiteContentView` handles all `extractionState` cases independently from full UI.
- **Double-click launch**: `AppDelegate.application(_:open urls:)` sets `viewModel.launchedByFileOpen = true`. On completion, if flag true + `BatchResult.allSucceeded`, auto-reveals first success in Finder, then quits after 0.5s delay. Any failure skips auto-close — shows `LiteContentView`'s minimal failure view (not full `ExtractionCompletedView`). `reset()` clears the flag. Password-protected archives follow same path (user types password in minimal prompt, clicks Extract, then auto-closes on success).
