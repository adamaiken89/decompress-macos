# Decompress — Product Specification

> **Author:** Product Review
> **Version:** 1.0.0
> **Platform:** macOS 15+ | Swift 6 | SPM | No external dependencies

---

## 1. Product Overview

**Decompress** is a native macOS decompression utility. It extracts 11 archive formats by wrapping system CLI tools (`ditto`, `tar`, `gunzip`, `bunzip2`, `unxz`, `unar`, `unzip`) via `Process`. No external dependencies, no sandbox — pure SwiftUI + system tools.

### Elevator Pitch

> Drop an archive, get your files. No ads, no telemetry, no Electron. A native Mac app that "just works."

---

## 2. Features Inventory

### 2.1 Archive Support (11 Formats)

| Format | Extensions | System Tool | Magic Bytes | Notes |
|---|---|---|---|---|
| ZIP | `.zip` | `ditto` / `unzip -P` | `PK\x03\x04` | Password detection via bit flag |
| TAR | `.tar` | `tar -xf` | — | |
| GZIP | `.gz` | `gunzip -f` | `\x1F\x8B` | |
| BZIP2 | `.bz2` | `bunzip2 -f` | `\x42\x5A` | |
| XZ | `.xz` | `unxz -f` | `\xFD\x37\x7A\x58\x5A\x00` | |
| TAR.GZ | `.tar.gz`, `.tgz` | `tar -xzf` | `\x1F\x8B` | Shares magic with GZIP |
| TAR.BZ2 | `.tar.bz2`, `.tbz2`, `.tbz` | `tar -xjf` | `\x42\x5A` | Shares magic with BZIP2 |
| TAR.XZ | `.tar.xz`, `.txz` | `tar -xJf` | shared with XZ | |
| 7Z | `.7z` | `unar -o` | `\x37\x7A\xBC\xAF\x27\x1C` | Requires `unar` |
| RAR | `.rar`, `.cbr` | `unar -o` | `\x52\x61\x72\x21\x1A\x07` | Requires `unar` |
| SPLIT | `.001` | `unar -o` | — | Requires `unar` |

### 2.2 User Interface

| Screen | Trigger | Contents |
|---|---|---|
| DragDropView | `.idle` state | Drop zone, file picker button, password toggle, file list, Extract/Clear buttons |
| ExtractionProgressView | `.preparing` / `.extracting` | Spinner or progress bar, file name, percentage, Cancel button |
| ExtractionCompletedView | `.completed` | Green checkmark, result summary (format, count, size, duration), Reveal/Extract Another |
| ExtractionFailedView | `.failed` | Red X, error message, Try Again button |
| HelpView | Menu / Toolbar | 3 tabs: Usage, Supported Formats, Tips |
| SettingsView | `Settings` menu | 2 tabs: General (auto-extract, trash toggle, output dir), Formats (supported list) |

### 2.3 Input Methods

- **Drag & drop** onto dashed-border drop zone
- **File picker** via `Cmd+O` or "Select Files" button (system `fileImporter`)
- **Format detection:** extension (longest match) → magic bytes (fallback)

### 2.4 Extraction Behavior

| Feature | Default | Persisted | Details |
|---|---|---|---|
| Extract to source directory | ON | Yes (Settings) | Creates `ArchiveName/` subfolder next to archive |
| Extract in place | OFF | No (per-session) | Extracts directly into archive's parent folder |
| Custom output directory | — | Yes (Settings) | Only active when auto-extract is OFF |
| Move to Trash after extraction | OFF | Yes (Settings) | Uses `NSWorkspace.shared.recycle()` |
| Password support | — | No | Detects ZIP encryption; manual toggle for others |

### 2.5 Keyboard Shortcuts

| Shortcut | Context | Action |
|---|---|---|
| `Cmd+O` | Global (menu) + button | Open file picker |
| `Cmd+E` | Global (menu) + button | Extract All |
| `Cmd+R` | Completed view | Reveal in Finder |
| `Cmd+N` / `Esc` | Completed view | Extract Another |
| `Cmd+?` | Global (menu) | Open Help |
| `Esc` | Progress view | Cancel |
| `Return` | Failed view | Try Again |

### 2.6 Accessibility

- `.accessibilityLabel()` on all interactive elements
- `.accessibilityHidden(true)` on decorative images
- `.accessibilityElement(children: .combine)` on grouped elements
- Selectable error message text
- Progress bar with percentage

### 2.7 Testing

| Suite | Tests | Scope |
|---|---|---|
| ArchiveFormatTests | 14 | Format metadata (extensions, magic bytes, display names) |
| DecompressionServiceTests | 24 | Format detection by extension, suggested destinations |
| DecompressViewModelTests | 25 | ViewModel state management, file add/remove/reset |
| DecompressUITests | 4 | Launch, window exists, UI elements visible |

---

## 3. User Flow

```
Launch App
   │
   ▼
[idle] Drop Zone —──────────────────────────┐
   │                                         │
   ├── Drag files onto zone                  │
   └── Cmd+O / "Select Files" ──────────────┘
   │
   ▼
Files detected → format badges shown
Password prompted if ZIP encryption detected
   │
   ▼
User clicks "Extract All" (Cmd+E)
   │
   ▼
[preparing → extracting] Progress bar, file name, %
   │                          └── Cancel (Esc)
   │
   ├── ✅ [completed] Result summary
   │       ├── Reveal in Finder (Cmd+R)
   │       └── Extract Another (Cmd+N / Esc)
   │
   └── ❌ [failed] Error message
           └── Try Again (Return)
```

---

## 4. Architecture Highlights

### MVVM + Actor

```
View ──► ViewModel (@Observable, @MainActor) ──► Service (actor)
                                                     │
                                                     ├── detectFormat() [nonisolated]
                                                     ├── extract() → ExtractionResult
                                                     └── isZipEncrypted() [nonisolated]
```

- **ViewModel** owns all UI state; views observe via `@Environment`
- **Service** is an `actor` — thread-safe via `Process` + `withCheckedThrowingContinuation`
- **Format detection** is `nonisolated` to be callable from any context
- `extractAll()` captures all values upfront to avoid actor isolation issues

### State Machine

```
idle ──► preparing ──► extracting ──► completed
                                    └──► failed (then back to idle)
Any state → idle (via reset/clear)
Extracting → idle (via cancel)
```

### Format Detection Strategy

1. **Extension first** — longest matching suffix wins (prevents `.tar.gz` from matching `.gz`)
2. **Magic bytes fallback** — reads first 16 bytes, checks all format magic arrays
3. Case-insensitive extension matching

---

## 5. Opportunities & Recommendations

### 5.1 High Impact, Low Effort

| # | Opportunity | Why |
|---|---|---|
| 1 | **Batch extraction progress** — show per-file progress (2/5 completed) instead of a single progress bar for all files | Currently only shows the current file's progress within a single archive, but nothing about progress across multiple selected archives |
| 2 | **Trash button in Failed view** — offer to trash the source archive when extraction fails | Failed corrupt archives sit around; user has to manually clean up |
| 3 | **Copy extracted file path** — right-click or button on completed view to copy destination path to clipboard | Power users often need the path for terminal workflows |
| 4 | **Default output location picker in Settings UX** — the "Choose..." button + "Not set" label is clean but users won't know they can set it without turning off auto-extract first | Add a hint or helper text explaining the dependency |
| 5 | **Open extracted folder** — add a button (or make "Reveal in Finder" have a dropdown) to open the folder instead of just selecting it | `Cmd+O` to open the folder is a common expectation |

### 5.2 Medium Impact, Medium Effort

| # | Opportunity | Why |
|---|---|---|
| 6 | **Split archive joining** — `.001` is listed but there's no UI or logic to handle multi-part splits (`.001`, `.002`, ...) | Currently only handles single `.001` files; multi-part RAR/ZIP splits are common in the wild |
| 7 | **Archive preview before extraction** — show file tree / contents before committing to extract | Users often want to peek inside before extracting; reduces unwanted extraction |
| 8 | **Password memory / keychain integration** — save passwords to macOS Keychain for specific encrypted archives | Re-extracting the same encrypted file requires re-entering password; no persistence |
| 9 | **Right-click / Quick Actions** — add a Finder Sync extension or Quick Action to "Extract with Decompress" from the context menu | Currently requires opening the app and dragging files in; reduces friction significantly |
| 10 | **Recent archives list** — show recently extracted archives with quick re-extract or reveal | Common usage pattern: extract, check files, extract again with different settings |

### 5.3 High Impact, High Effort

| # | Opportunity | Why |
|---|---|---|
| 11 | **Create / Compress archives** — add compression support (zip, tar.gz, etc.) | Currently extract-only; users often need both directions. Would double the app's value proposition but requires significant new tooling and UI |
| 12 | **Image/HEIC preview + extract** — macOS 15+ HEIC/HEIF image extraction (common in camera downloads) | Many users download camera archives (`.heic.zip`) and need quick preview before extraction |
| 13 | **Drag files out of the app** — allow dragging individual files from the completed results out to Finder | Currently you must "Reveal in Finder" then drag from there; one extra step |
| 14 | **Batch settings profiles** — save named extraction profiles (e.g., "Photos: extract in place, trash source" vs "Dev: extract to ~/Downloads, keep source") | For power users who extract different types of archives differently |
| 15 | **Menu bar app / background mode** — run as a menu bar app with global hotkey for paste-extract (copy archive, press hotkey, it extracts to ~/Downloads) | 10x faster workflow for frequent extractors |

### 5.4 User Experience Polish

| # | Opportunity | Why |
|---|---|---|
| 16 | **Haptic feedback** on drop, completion, and failure | macOS supports haptic trackpad feedback; adds satisfying tactile response |
| 17 | **Animated transitions** between states — currently views switch instantly | Smooth crossfade or slide adds perceived polish |
| 18 | **Window title** updates with current archive name | Currently always just "Decompress" |
| 19 | **Drag multiple archives simultaneously** — current drop zone handles multiple files but the drag experience could be improved with visual stacking | Showing a "badge count" on the drop zone during multi-file drags |
| 20 | **Sound effects** — play macOS system sounds on completion/failure (opt-in) | Accessibility feature and user preference |

---

## 6. Uselessness Analysis

### 6.1 Over-Engineering / Low Value

| Item | Issue | Recommendation |
|---|---|---|
| **`uniqueDirectoryURL` counter logic** | Handles naming collisions by appending `" 1"`, `" 2"`, etc. — this is used in exactly one place and is tested thoroughly. In practice, extraction to a fresh directory rarely conflicts. | Low risk, fine to keep, but doesn't add meaningful UX value over a simple UUID or timestamp suffix. |
| **`detectFormatByMagicBytes`** | Reads first 16 bytes and checks 7 magic byte arrays sequentially. In practice, extension detection catches 99%+ of cases. Magic bytes add correctness for misnamed/recovered files but most users never trigger this path. | Keep as a correctness fallback, but it's polish for an edge case. |
| **`formattedDuration` with `DateComponentsFormatter`** | Uses `DateComponentsFormatter` with `.abbreviated` style (e.g., "0s", "1m 30s"). Most extractions complete in under 5 seconds. The duration display is often "0s" or "1s". | The duration display is near-zero for most use cases. Consider hiding it when < 1s, or only showing for extractions > 3s. |
| **`isZipEncrypted` — manual bit flag parsing** | Reads raw bytes and checks bit 0 of byte 6. This is correct per the ZIP spec, but only ZIP is supported for auto-detection. 7Z/RAR encryption is not auto-detected — user must manually toggle the password switch. | Inconsistent. Either auto-detect encryption for all formats (via `unar` output parsing) or remove the special-case ZIP detection and let user toggle manually for all. |
| **`AccessibilityElement(children: .combine)` on `FileRowView`** | Groups filename, format badge, and remove button as a single accessibility element. This means a VoiceOver user cannot individually interact with the remove button. | Should be `.contain` or individual labels for the remove action, not `.combine`. |
| **Toolbar Clear button hidden when idle** | The Clear button has conditional visibility based on idle state. The `isIdle` check means it only shows during non-idle states. But the `reset()` method it calls already handles this fine. | Minor — the visibility condition adds code complexity without real user benefit. Could just always show it, disabled, for consistency. |
| **`showHelp` as ViewModel property** | The help window is opened by setting `viewModel.showHelp = true`, and `ContentView` observes this and opens the window. This is an odd pattern — the window is opened imperatively via `NSWindow` but triggered through the ViewModel. | The help window is controlled by scene state (`Window(id: "help")`), which is a SwiftUI native pattern. Using the ViewModel as a trigger for a scene is a workaround. Consider using `@FocusedValue` or a static `@AppStorage` instead. |

### 6.2 Missing or Broken

| Item | Issue |
|---|---|
| **`DecompressUITests` target not in `Package.swift`** | The UI test files exist on disk but the test target is not declared in `Package.swift`. These tests will never run in CI. |
| **No `.xcodeproj` or workspace** | SPM-only means no Xcode project. This is fine for SPM but makes it impossible to run UI tests (which require an XCTest plan / scheme). The UI tests are effectively dead code. |
| **`unar` required for 3 formats but not bundled** | 7Z, RAR, and SPLIT formats require `unar` to be installed at one of 3 hardcoded paths. If the user doesn't have Homebrew, the app shows a cryptic error. No fallback, no installation prompt. |

### 6.3 Speculative — Might Be Over-Built

| Item | Analysis |
|---|---|
| **Pre-commit git hook** | Runs SwiftLint + Swift build on every commit. Valuable for CI discipline, but slows down local commits. Many devs will skip with `--no-verify`. |
| **Custom app icon generation in `make-app-bundle.sh`** | Generates a 1024×1024 icon programmatically with `sips` + `iconutil`. This is clever but fragile (depends on `sips` and `iconutil` being available). A pre-made `.icns` file would be simpler. |
| **SwiftLint with 64 opt-in rules** | 64 opt-in rules plus 3 analyzer rules is aggressive. Some rules (`file_name`, `multiline_arguments`, `closure_spacing`, `redundant_nil_coalescing`, `unavailable_function`) are pedantic and may slow development without meaningful quality improvement. |

---

## 7. Competitive Landscape

| App | Strengths | Weaknesses vs Decompress |
|---|---|---|
| **The Unarchiver** | Free, mature, handles 40+ formats | Mac App Store sandbox restricts system tool access; Electron-based on Mac |
| **Keka** | Compression + extraction, batch processing | Paid (App Store) / donationware; less native feel |
| **BetterZip** | Preview before extract, compression, Quick Actions | Paid ($24.95); overkill for simple extraction |
| **Archive Utility (built-in)** | Free, always available, zero install | No batch UI, no password support, no trash option, no progress feedback |
| **macOS `tar` / `unzip` CLI** | Full power, scriptable | Terminal-only, no UI |

**Decompress's niche:** Modern, native SwiftUI app for macOS 15+ with no Electron, no sandbox restrictions, and a clean minimal UI. Competes with The Unarchiver on UX quality while being more Mac-native.

---

## 8. Recommended Roadmap

### v1.1 (Quick Wins)
- Batch extraction progress (across archives, not just within)
- Right-click / Quick Action via Finder Sync
- Keychain password integration
- Open folder from Completed view (not just Reveal)

### v1.2 (Feature Expansion)
- Archive preview (peek inside before extracting)
- Recent archives list
- Drag files out of completed results
- Trash button on Failed view

### v2.0 (Major)
- Compression / archive creation (ZIP, TAR.GZ)
- Menu bar mode with global hotkey
- Batch settings profiles
- Multi-part split archive joining UI

---

## 9. Key Metrics to Track

1. **Extraction success rate** — % of extractions that complete without error
2. **Format distribution** — which formats are most common (to prioritize testing)
3. **Password usage rate** — how often encryption is used (to prioritize keychain integration)
4. **`unar` missing rate** — how often 7Z/RAR/SPLIT fail because `unar` is not installed
5. **Cancel rate** — how often users cancel mid-extraction (indicates performance or wrong archive)
