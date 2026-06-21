# Decompress — Development Plan

> Implementation plans for remaining features, ordered by effort.

---

## Dependency Reference

### Bundled with macOS 15+ (no install needed)

| Tool | Path | Used For |
|---|---|---|
| `ditto` | `/usr/bin/ditto` | ZIP extraction & creation |
| `unzip` | `/usr/bin/unzip` | ZIP extraction with password |
| `zip` | `/usr/bin/zip` | ZIP creation |
| `tar` / `bsdtar` | `/usr/bin/tar` → `bsdtar` | TAR/TAR.GZ/TAR.BZ2/TAR.XZ extract & create |
| `gunzip` | `/usr/bin/gunzip` | GZIP decompression |
| `gzip` | `/usr/bin/gzip` | GZIP compression |
| `bunzip2` | `/usr/bin/bunzip2` | BZIP2 decompression |
| `bzip2` | `/usr/bin/bzip2` | BZIP2 compression |

### Requires Homebrew (optional, format-dependent)

| Tool | Install | Used For |
|---|---|---|
| `unar` | `brew install unar` | 7Z, RAR, SPLIT extraction; archive listing |
| `unxz` | `brew install xz` | XZ decompression |

### Minimum dependency for ALL features

```
Mandatory:    (none — everything in macOS 15+)
            /usr/bin/ditto, /usr/bin/unzip, /usr/bin/zip,
            /usr/bin/tar(bsdtar), /usr/bin/gunzip, /usr/bin/gzip,
            /usr/bin/bunzip2, /usr/bin/bzip2

Optional:   brew install unar      # 7Z, RAR, SPLIT + archive preview
            brew install xz         # XZ / TAR.XZ (can skip if not needed)
```

No external Swift dependencies. No frameworks beyond SwiftUI + Foundation.

---

## Phase 1: Quick Wins (1–2 days each)

### P1.2 — Open extracted folder (not just Reveal)

**Problem:** "Reveal in Finder" selects the file in Finder. Users often want to open the folder to browse contents.

**Solution:**

Add a second button "Open Folder" (`Cmd+Shift+O`) that calls:

```swift
NSWorkspace.shared.open(destinationURL)
```

Add to `ExtractionCompletedView` alongside "Reveal in Finder."

**Dependencies:** None.

**Files:**
- `ExtractionCompletedView.swift` — add button

---

### P1.3 — Copy extracted path to clipboard

**Problem:** Power users need the extracted path for terminal/script workflows.

**Solution:**

Add a "Copy Path" button (or context menu) on `ExtractionCompletedView`:

```swift
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(result.destinationURL.path, forType: .string)
```

Could also add a small copy icon next to the destination path in the result summary.

**Dependencies:** None.

**Files:**
- `ExtractionCompletedView.swift` — add copy button

---

## Phase 2: Medium Features (3–5 days each)

### P2.2 — Keychain password integration

**Problem:** Encrypted archives require password re-entry every session. No persistence.

**Solution:**

Use Security framework (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`) to store/retrieve passwords keyed by source file path.

1. **New Service:** `KeychainService` with:
   - `storePassword(_:for:)` — SecItemAdd with `kSecClassGenericPassword`
   - `retrievePassword(for:)` — SecItemCopyMatching
   - `deletePassword(for:)` — SecItemDelete

2. **ViewModel:** On successful extraction with password, offer to "Remember password." On subsequent extraction of same file, auto-fill password.

3. **UX:** Add `"Save to Keychain"` checkbox in `PasswordPromptView` (shown only after first successful extraction with that password).

**Dependencies:** None (`Security.framework` is part of macOS).

**Files:**
- `Sources/Decompress/Services/KeychainService.swift` — new file
- `DecompressViewModel.swift` — integrate keychain calls
- `PasswordPromptView.swift` — add "Save" toggle

---

### P2.3 — Finder Sync / Quick Action

**Problem:** Must open app + drag files in. No right-click "Extract with Decompress" in Finder.

**Solution:**

Two parts:

**A) Quick Action (Automator/Workflow)**
- Create a workflow `.workflow` file that receives archive files and opens them with Decompress.
- Ship it in the `.app` bundle (`Decompress.app/Contents/Resources/`).

**B) URL Scheme**
- Register custom URL scheme `decompress://extract?path=...` in `Info.plist`.
- `DecompressApp.swift` handles `onOpenURL` and calls `viewModel.addFiles()`.

Combined: Install the Quick Action → right-click archive → "Quick Actions" → "Extract with Decompress." The workflow passes the file path via the URL scheme.

**Simpler alternative (recommended):** Register Decompress as a handler for archive UTIs in `Info.plist`. Then Finder already shows "Open With → Decompress" in the right-click menu. This requires zero custom workflow code.

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.zip-archive</string>
            <string>public.tar-archive</string>
            <!-- ... etc -->
        </array>
    </dict>
</array>
```

Then in `DecompressApp.swift`, handle `NSApplicationDelegate` `application(_:openFile:)` or `onOpenURL`.

**Status:** Partially done — `CFBundleDocumentTypes` in Info.plist registers file extensions but uses `CFBundleTypeExtensions` not `LSItemContentTypes`. No URL scheme or Quick Action workflow.

**Dependencies:** None.

**Files:**
- `support/Info.plist` — add `CFBundleDocumentTypes` and URL scheme
- `DecompressApp.swift` — add `onOpenURL` / app delegate handler
- `scripts/make-app-bundle.sh` — ensure Info.plist is bundled
- (Optional) Quick Action `.workflow` file

---

### P2.4 — Recent archives list + re-extract

**Problem:** No history of what was extracted. Common pattern: extract, check files, extract again with different settings.

**Solution:**

1. **`RecentArchive` model:**
   ```swift
   struct RecentArchive: Codable, Hashable, Sendable {
       let sourceURL: URL
       let format: ArchiveFormat
       let destinationURL: URL
       let date: Date
   }
   ```

2. **Persist to `UserDefaults` / `@AppStorage`** — store JSON-encoded array of recent archives (max 20).

3. **ViewModel:** Add `recentArchives: [RecentArchive]` loaded from storage. Append on each successful extraction.

4. **DragDropView:** When idle, show a "Recent" section below the drop zone with a compact list. Each row shows archive name, format badge, date, and action buttons (Reveal, Extract Again).

5. **Settings:** Add "Clear Recent Archives" button.

**Dependencies:** None.

**Files:**
- `Sources/Decompress/Models/RecentArchive.swift` — new file
- `DecompressViewModel.swift` — add storage + methods
- `DragDropView.swift` — add recent section
- `Sources/Decompress/Views/RecentArchiveRowView.swift` — new file
- `SettingsView.swift` — add clear button

---

### P2.5 — Archive preview before extraction

**Problem:** Users can't see what's inside an archive before extracting. They extract blindly.

**Solution:**

Use available tools to list archive contents without extracting:

| Format | Command |
|---|---|
| ZIP | `unzip -l <file>` |
| TAR/GZ/BZ2/XZ | `tar -tf <file>` |
| 7Z/RAR/SPLIT | `unar -l <file>` |

1. **DecompressionService:** Add `listContents(of:) async throws -> [String]` method.

2. **ViewModel:** Add preview state: `showPreview: Bool`, `previewContents: [String]`, `previewURL: URL?`.

3. **New View:** `ArchivePreviewView` — sheet or popover showing file tree, total size, file count. "Extract" button at bottom.

4. **DragDropView:** Add "Preview" button (eye icon) next to each file in the selected list. Or add a "Preview" button before Extract All.

**Status:** Partially done — `listContents(of:)` exists in `DecompressionService+ContentListing`. ViewModel has `previewArchives()` + `ExtractionState.browsing` + `ArchiveContentView` (full-screen file list with checkboxes). Differs from plan: uses full state transition instead of sheet/popover.

**Dependencies:** Depends on `unar` for 7Z/RAR/SPLIT preview. ZIP and TAR use bundled tools.

**Files:**
- `DecompressionService.swift` — add `listContents(of:)`
- `DecompressViewModel.swift` — add preview state
- `Sources/Decompress/Views/ArchivePreviewView.swift` — new file
- `DragDropView.swift` or `FileRowView.swift` — add preview button

---

## Phase 3: Major Features (1–2 weeks each)

### P3.1 — Archive creation (Compression)

**Problem:** Extract-only. Users need to go to other tools to create archives.

**Solution:**

**Supported creation formats:**

| Format | Tool | Command |
|---|---|---|
| ZIP | `ditto` | `ditto -c -k <source> <dest>.zip` |
| ZIP | `zip` | `zip -r <dest>.zip <source>` |
| TAR | `tar` | `tar -cf <dest>.tar <source>` |
| TAR.GZ | `tar` | `tar -czf <dest>.tar.gz <source>` |
| TAR.BZ2 | `tar` | `tar -cjf <dest>.tar.bz2 <source>` |
| GZIP | `gzip` | `gzip -c <source> > <dest>.gz` |
| BZIP2 | `bzip2` | `bzip2 -c <source> > <dest>.bz2` |

(No 7Z/RAR creation — they require proprietary tools.)

**New Service Method:**
```swift
func createArchive(
    sourceURLs: [URL],
    destinationURL: URL,
    format: ArchiveFormat,
    progressHandler: @Sendable @escaping (Double, String) -> Void
) async throws
```

**New UI:**
- Add a toggle/segmented control in DragDropView: "Extract" | "Create"
- "Create" mode: drop zone accepts files/folders, shows format picker, destination picker, "Create" button
- Progress view and completion view for creation

**Files:**
- `DecompressionService.swift` — add creation methods
- `DecompressViewModel.swift` — add creation mode state
- `DecompressApp.swift` — potentially add new menu commands
- `DragDropView.swift` — add mode toggle
- `Sources/Decompress/Views/CreateArchiveView.swift` — new file (or extend DragDropView)

**Dependencies:** None (`ditto`, `zip`, `tar`, `gzip`, `bzip2` all bundled).

---

### P3.2 — Menu bar mode with global hotkey

**Problem:** Must keep app window open. No quick-access extraction from anywhere.

**Solution:**

1. **AppDelegate pattern:** Add `@NSApplicationDelegateAdaptor` to `DecompressApp`. Detect Cmd+click or a Settings toggle to switch between windowed and menu bar mode.

2. **MenuBarExtra scene** (SwiftUI 3+/macOS 13+):
   ```swift
   MenuBarExtra("Decompress", systemImage: "doc.zipper") {
       // Quick extract from clipboard
       // Recent archives
       // Open Decompress
       // Quit
   }
   ```

3. **Global hotkey:** Use `CGEvent` or `EventMonitor` to register a global shortcut (e.g., `Cmd+Shift+X`). On trigger, paste file from Finder clipboard and extract.

4. **Paste-extract flow:** Detect archive file on `NSPasteboard.general`, extract to `~/Downloads`, show notification.

**Dependencies:** None.

**Files:**
- `DecompressApp.swift` — add `MenuBarExtra` or AppDelegate for mode switching
- `Sources/Decompress/Services/HotkeyService.swift` — new file
- `SettingsView.swift` — add "Launch at login" + "Menu bar mode" + "Global hotkey"

---

### P3.3 — Drag files out of completed results

**Problem:** After extraction, user must "Reveal in Finder" then drag from there. One extra step.

**Solution:**

Use `NSDraggingSource` / SwiftUI `.onDrag` on the result items in `ExtractionCompletedView`. Allow dragging the destination folder (or individual files) directly out of the app window.

**Implementation:**
```swift
// In ExtractionCompletedView
VStack {
    // result details
}
.onDrag {
    NSItemProvider(item: result.destinationURL as NSSecureCoding, typeIdentifier: UTType.fileURL.identifier)
}
```

Also allow dragging individual files from a file list view within the completed results.

**Dependencies:** None.

**Files:**
- `ExtractionCompletedView.swift` — add `.onDrag` to destination
- `ExtractionResult.swift` — ensure Sendable conformance for drag

---

### P3.4 — Multi-part split archive joining UI

**Problem:** `.001` format implies multi-part splits (`.001`, `.002`, ...). Currently only handles single `.001` files. `unar` can handle multipart, but there's no UI for selecting all parts.

**Solution:**

1. **Detection:** When user adds a `.001` file, scan the same directory for sequential parts (`.002`, `.003`, etc.). Auto-add them to the selection.

2. **Grouping:** Group related parts in the file list. Show as a single item "archive.7z.001 (+ 3 parts)."

3. **Extraction:** Pass only the `.001` file to `unar` — it automatically finds and joins the rest.

**Dependencies:** Requires `unar`.

**Files:**
- `DecompressViewModel.swift` — add part detection in `addFiles()`
- `FileRowView.swift` — show part count badge

---

### P3.5 — Batch settings profiles

**Problem:** Users extract different archive types differently. Photos → extract in place + trash. Dev downloads → extract to ~/Downloads + keep.

**Solution:**

1. **`ExtractionProfile` model:**
   ```swift
   struct ExtractionProfile: Codable, Identifiable {
       let id: UUID
       var name: String
       var autoExtractToSourceDir: Bool
       var deleteArchiveAfterExtraction: Bool
       var extractInPlace: Bool
       var outputDirectoryURL: URL?
   }
   ```

2. **Profile selector** in the toolbar or as a dropdown above the Extract All button.

3. **Profile management** in Settings (add, edit, delete, duplicate).

4. **Quick switch** — clicking the profile selector applies that profile's settings immediately.

**Dependencies:** None.

**Files:**
- `Sources/Decompress/Models/ExtractionProfile.swift` — new file
- `DecompressViewModel.swift` — add profile state + persistence
- `DragDropView.swift` — add profile picker
- `SettingsView.swift` — add profile management UI

---

## Phase 4: UX Polish (half-day each)

### P4.1 — Haptic feedback

```swift
import AppKit
// On drop:
NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
// On completion:
NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
```

**Files:** `DragDropView.swift`, `ExtractionCompletedView.swift`, `ExtractionFailedView.swift`

### P4.2 — Animated state transitions

Use `.transition(.opacity.combined(with: .scale))` on ContentView's state-switching views. Or `.matchedGeometryEffect` for shared elements.

**Status:** Partial — ContentView uses `.spring` animation on `extractionState` changes with `.scale.combined(with: .opacity)` transitions. No `matchedGeometryEffect`.

**Files:** `ContentView.swift`

### P4.3 — Window title updates

Set window title to current archive name during extraction. Use `.navigationSubtitle()` or `NSWindow` title via `.windowToolbarStyle`.

**Files:** `DragDropView.swift`, `ContentView.swift`

### P4.4 — Sound effects on completion/failure

```swift
NSSound(named: "Glass")?.play()  // success
NSSound(named: "Basso")?.play()  // failure
```

Opt-in via Settings.

**Files:** `ExtractionCompletedView.swift`, `ExtractionFailedView.swift`, `SettingsView.swift`

### P4.5 — Fade-in notification banners

Instead of switching views instantly, show a brief animated banner "Extraction Complete" / "X files extracted" that auto-dismisses after 3s, keeping the user in the current context.

**Files:** `ContentView.swift`, new `NotificationBannerView.swift`

---

## Remaining Cleanup

| Issue | Phase | Fix | Status |
|---|---|---|---|
| ZIP-only encryption detection | P2.2 | Unify: always show password toggle when encrypted format detected. Remove `isZipEncrypted` in favor of `unar` output parsing for all formats. | ❌ |
| `FileRowView` accessibility `.combine` | P1.1 | Change to `.contain` so remove button is individually accessible. | ✅ Already `.contain` |
| UI tests target not in Package.swift | P1.1 | Add `DecompressUITests` target to `Package.swift` (depends on `Decompress` target). | ❌ |
| `showHelp` as ViewModel property | P4.2 | Replace with `@FocusedValue` or `@Environment(\.openWindow)` for native SwiftUI window control. | ❌ Still in ViewModel (`.openWindow` added but boolean remains) |
| Toolbar Clear button hidden when idle | P1.1 | Always show, disabled when idle. Remove conditional `hide` logic. | ✅ Always visible, disabled when empty |

---

## Dependency Summary Table

| Feature | `unar` | `xz` | System tools only |
|---|---|---|---|
| P1.2 Open folder | | | ✓ |
| P1.3 Copy path | | | ✓ |
| P2.2 Keychain passwords | | | ✓ |
| P2.3 Quick Action / UTI | | | ✓ |
| P2.4 Recent archives | | | ✓ |
| P2.5 Archive preview | ✓ | ✓ | ✓ (ZIP/TAR only without unar) |
| P3.1 Archive creation | | | ✓ |
| P3.2 Menu bar mode | | | ✓ |
| P3.3 Drag out results | | | ✓ |
| P3.4 Split joining UI | ✓ | | |
| P3.5 Settings profiles | | | ✓ |
| P4.1–4.5 Polish | | | ✓ |

**Takeaway:** Only **2 features** truly need `unar`. Everything else runs on system tools.

---

## Recommended Build Order

```
Week 1:  P1.2 + P1.3 + remaining cleanup
         → Open folder, copy path, fix UITests target, showHelp refactor

Week 2:  P2.3 + P2.4
         → Finder UTI registration + recent archives history

Week 3:  P2.2 + P2.5
         → Keychain + preview polish (unar dep)

Week 4-5: P3.1
         → Creation (biggest feature, doubles app value)

Week 6:  P3.2 + P3.3
         → Menu bar + drag-out (power user features)

Week 7:  P3.4 + P3.5
         → Split joining + profiles (niche but complete)

Week 8:  P4.1–4.5
         → Polish pass (haptics, animation, sounds, window title)
```
