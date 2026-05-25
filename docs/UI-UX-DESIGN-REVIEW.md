# Decompress — Desktop UI/UX Design Review

> **Reviewer:** Desktop UI/UX Design  
> **Scope:** Button usage, layout architecture, user workflow  
> **Platform:** macOS 15+ | SwiftUI  
> **Date:** 2026-05-31

---

## 1. Button Usage Review

### 1.1 Primary / Secondary Hierarchy

The app correctly distinguishes primary from secondary actions:

| Button | Style | Correct? | Notes |
|--------|-------|----------|-------|
| Select Files | `.borderedProminent` + `.controlSize(.large)` | ✅ | Appropriate for the sole primary action in the idle state |
| Extract All | `.borderedProminent` + `Cmd+E` | ✅ | Strong visual affordance for the main action |
| Reveal in Finder | `.borderedProminent` + `Cmd+R` | ✅ | Matches user expectation |
| Extract Another | `.borderedProminent` + `Cmd+N` | ✅ | Clear call-to-action |
| Try Again | `.borderedProminent` + `Return` | ✅ | Logical primary action on failure |
| Clear (content) | `.bordered` + `Esc` | ✅ | Secondary/destructive, lower prominence |
| Cancel | `.bordered` (role: `.cancel`) + `Esc` | ✅ | Appropriate styling for cancellation |
| Move to Trash | `.bordered` + `Cmd+Delete` | ✅ | Destructive action, secondary prominence |

### 1.2 Issues

#### 1.2.1 `Extract Another` has conflicting keyboard shortcuts

**File:** `ExtractionCompletedView.swift:67-68`

```swift
.keyboardShortcut(.escape)
.keyboardShortcut("n")
```

Two `.keyboardShortcut()` modifiers on the same button. SwiftUI only respects the last one (`Cmd+N`), making `Esc` on this button a no-op. `Esc` should either be removed (it's already used for Cancel in the progress view) or re-assigned to a different button.

#### 1.2.2 Toolbar `Clear` button conditional visibility

**File:** `ContentView.swift:30-35`

The Clear button is only shown when `isIdle == false`. This causes the toolbar to visually shift when state changes. Standard macOS convention is to always show toolbar items and disable them when unavailable. The current approach creates layout jitter as buttons appear/disappear.

**Recommendation:** Always show the Clear button, disabled when idle/busy. Alternatively, keep Help in a fixed position and always show Clear (disabled when inappropriate).

#### 1.2.3 `FileRowView` remove button — accessibility issue

**File:** `FileRowView.swift:30-36`

The row uses `.accessibilityElement(children: .combine)`, which merges filename + format badge + remove button into a single VoiceOver element. The remove button becomes inaccessible to screen reader users who cannot individually activate it.

**Recommendation:** Change to `.accessibilityElement(children: .contain)` so the remove button is individually focusable by VoiceOver.

#### 1.2.4 `PasswordPromptView` uses `.font(.caption)` for primary controls

**File:** `PasswordPromptView.swift`

The password toggle and SecureField are styled at `font(.caption)` — too small for a primary interaction point. Password entry is a critical path action; it should be at `.subheadline` or `.body` size. This also creates visual weight imbalance: tiny input field below a large `.borderedProminent` button.

---

## 2. Layout Review

### 2.1 App Window

- **Min size:** 520×420 — reasonable. Content fits without clipping.
- **Window resizability:** `.contentMinSize` — correct. Users can resize but not below functional minimum.
- **Padding:** 20pt top-level padding — consistent with HIG.
- **Spacing hierarchy:** 16-20pt for sections, 8pt for related controls, 4pt for tight text — correctly applied throughout.

### 2.2 Drop Zone (DragDropView)

**Current layout (idle):**
```
[Spacer]
[doc.zipper icon — 64pt]
["Drop archives here" — title3]
["ZIP, TAR, GZIP, BZIP2, XZ, 7Z, RAR" — caption]
[instruction text — caption2]
[format hint — caption]
[Spacer]
[Select Files — borderedProminent, large]
[PasswordPromptView — caption]
[Spacer]
```

**Issues:**
1. **Password prompt visible at idle** — The password toggle appears before any file is selected. A user who has never used the app sees a "Password required" toggle with no context. This is premature disclosure and causes confusion.
2. **Vertical center is crowded** — The icon + 4 lines of instructional text + Select Files button + password prompt are all stacked in the center with `Spacer()` top and bottom. On larger windows, the content floats in the middle with excessive empty space above/below.

**Recommendation:**
- Hide `PasswordPromptView` entirely until at least one file is selected and encryption is detected.
- Consider a two-thirds / one-third vertical split instead of pure centering: drop zone instructions in the upper portion, password + options in the lower portion.

**Current layout (files selected):**
```
[selectedFilesSection]
[ScrollView of FileRowView]
[extractionOptions — Extract in place toggle]
[actionButtons — Clear | Extract All]
```

### 2.3 Extraction Progress (ExtractionProgressView)

**Issues:**
1. **Spinner + progress bar redundancy** — When the state is `.extracting`, both an indeterminate `ProgressView()` spinner AND a determinate `ProgressView(value:)` bar are shown. The spinner is shown for all extracting states, including when a determinate progress bar is available. This is redundant and visually noisy.
2. **Current file label layout** — The file name (`currentFile`) uses `.lineLimit(1)` with no truncation mode specified. Long paths will clip without visual indication.

### 2.4 Extraction Completed (ExtractionCompletedView)

**Layout:**
```
[Spacer]
[checkmark icon — 48pt, green]
["Extraction Complete" — title2]
[result rows (format, files, size, duration, location)]
[4 x borderedProminent buttons]
[Spacer]
```

**Issues:**
1. **Button density** — Four `.borderedProminent` buttons in a row creates visual overload and risks text truncation at narrow widths: "Reveal in Finder", "Open Folder", "Copy Path", "Extract Another". At 520px min width they fit, but any narrower and they break.
2. **No secondary button variant** — All four completed-view buttons use `.borderedProminent`. "Copy Path" and "Open Folder" could be `.bordered` to reduce visual competition with the primary actions (Reveal in Finder, Extract Another).

### 2.5 Help View

- Three-tab layout with `minWidth: 480, minHeight: 360` — good.
- Content constrained to `maxWidth: 520` — good for readability.
- `.tabItem` labels use `Label` with SF Symbols — consistent.

### 2.6 Settings View

- Fixed frame 480×300 — this is quite tight. The Formats tab has a `List` that could scroll but at 300pt height, only ~7 items are visible before scrolling. 11 formats are listed, so 4 are below the fold.
- The General tab's "Default output location" section uses `.disabled(viewModel.autoExtractToSourceDir)` to disable the entire section. The user sees grayed-out text and a "Choose..." button without explanation. They must infer the dependency between the toggle above and the section below. Add a subtle helper text: "Turn off 'Extract to source directory' to choose a custom location."

---

## 3. Workflow Review

### 3.1 State Machine

```
idle → preparing → extracting → completed
                               ↘ failed
Any state → idle (via reset/clear)
Extracting → idle (via cancel)
```

Clean and well-defined. The four states map cleanly to four views via a `switch` in `ContentView`. No ambiguous states.

### 3.2 User Flow Analysis

```
Launch → [idle] Drop zone visible
  ↓ Drag files or Select Files
[file list appears] → password + options + action buttons
  ↓ Extract All
[progress] → can cancel
  ↓ Success
[completed] → reveal / open / copy / extract another
  ↓ Failure
[failed] → try again / trash source
```

**Strengths:**
- Linear, predictable flow
- Single primary action at each step (Select Files → Extract All → Reveal/Extract Another)
- Keyboard shortcuts at every decision point
- Clear affordance for each state

**Issues:**

#### 3.2.1 Batch extraction — single failure loses all files

**File:** `DecompressViewModel.swift:120-140`

When multiple files are dropped and `extractAll()` iterates through them, a failure on archive #2 of 5 immediately transitions to `.failed` state. Archives #3–5 are never attempted, and the success results from archive #1 are lost (not shown to the user). The user must:
1. Manually find and re-extract archives #1 (again), #3, #4, #5
2. Fix the corrupt #2 separately

**Recommendation:** Continue extraction on failure. Show partial results with per-file status. Surface errors inline alongside completed results, not as a blocking modal state.

#### 3.2.2 No way to return to file list without resetting

From the `ExtractionCompletedView`, the only action is "Extract Another" which calls `reset()` and returns to idle. There is no way to:
- Keep the current file list and change options (e.g., re-extract with a different password or output location)
- View the file list after extraction without starting over

**Recommendation:** Consider a "Back to file list" option that returns to the file list view without clearing selected files, preserving the extraction result in a summary area.

#### 3.2.3 Password prompt timing is premature

`PasswordPromptView` is rendered inside the drop zone even before any files are selected. The password toggle and SecureField appear on launch. This is problematic because:
- User has no context for what the password is for
- User might toggle it on, enter a password, then select files — but the password was entered for nothing
- The "Password required" toggle is visually emphasized (uses `Label` with `lock` SF symbol) but actually has no effect until files are added

**Recommendation:** Only show `PasswordPromptView` after:
1. At least one file is selected
2. An encrypted format is detected (via `checkForEncryptedArchives`)

For non-ZIP encrypted formats (7Z, RAR), add a small "Password?" button or icon next to each file row that reveals a per-file SecureField.

#### 3.2.4 Progressive disclosure is uneven

- Password prompt: shown too early (always visible)
- Extract in place: shown only after files are selected (correct progressive disclosure)
- Format detection: results shown as badges (good visual feedback)
- Archive count: shown in section header (good)

The password prompt should follow the same progressive disclosure pattern as "Extract in place."

#### 3.2.5 No confirmation before extraction

When the user clicks "Extract All," extraction begins immediately with no confirmation dialog. This is fine for the current scope (fast, single-file extractions), but could be problematic if:
- User accidentally drops 20 large archives
- User misconfigured password or output location
- The "Move to Trash" setting is enabled

**Recommendation:** Add a brief (1-second) countdown or a non-blocking "Starting extraction..." announcement before the first archive is processed, to give the user a moment to cancel if they made a mistake.

---

## 4. Summary of Recommendations

### Priority: High

| # | Issue | Impact | File(s) |
|---|-------|--------|---------|
| 1 | Batch failure loses all progress | Data loss / user frustration | `DecompressViewModel.swift` |
| 2 | Password prompt shown before file selection | Confusing UX | `DragDropView.swift`, `PasswordPromptView.swift` |
| 3 | `Extract Another` has dual conflicting shortcuts | Dead shortcut | `ExtractionCompletedView.swift` |
| 4 | `FileRowView` accessibility `.combine` hides remove button | Barrier for VoiceOver | `FileRowView.swift` |

### Priority: Medium

| # | Issue | Impact | File(s) |
|---|-------|--------|---------|
| 5 | Toolbar Clear button appears/disappears | Layout jitter, non-standard | `ContentView.swift` |
| 6 | No return to file list after extraction | Poor retry workflow | `ExtractionCompletedView.swift`, `DecompressViewModel.swift` |
| 7 | Password prompt uses `.caption` font | Readability | `PasswordPromptView.swift` |
| 8 | Spinner + progress bar shown simultaneously | Visual redundancy | `ExtractionProgressView.swift` |
| 9 | Settings Formats tab partially below fold on open | Content hidden | `SettingsView.swift` |

### Priority: Low

| # | Issue | Impact | File(s) |
|---|-------|--------|---------|
| 10 | All completed-view buttons use `.borderedProminent` | Flat hierarchy | `ExtractionCompletedView.swift` |
| 11 | `currentFile` label has `.lineLimit(1)` without truncation | Path clipping | `ExtractionProgressView.swift` |
| 12 | Settings view disabled section has no helper text | Confusing dependency | `SettingsView.swift` |
| 13 | No animated state transitions | Instant switching feels abrupt | `ContentView.swift` |
| 14 | No confirmation before batch extraction | Potential user error | `DecompressViewModel.swift` |

---

## 5. Visual Consistency Check

| Element | Status | Notes |
|---------|--------|-------|
| SF Symbol usage | ✅ | Consistent throughout |
| Color palette (accent, secondary, tertiary) | ✅ | Proper semantic colors |
| Corner radius (8, 12) | ✅ | Consistent |
| Dash pattern on drop zone (8) | ✅ | As specified |
| `.controlSize(.large)` on primary buttons | ✅ | Consistent |
| Keyboard shortcut coverage | ✅ | Every view has shortcuts |
| Accessibility labels | ✅ | Present on all interactive elements |
| `.help()` tooltips | ✅ | Present on most controls |
| `multilineTextAlignment(.center)` | ✅ | Used appropriately |
| No inline private views | ✅ | Each view has its own file |

---

## 6. Conclusion

Decompress has a well-architected UI with strong adherence to macOS conventions and its own design system. The button hierarchy, spacing system, and state machine are thoughtfully implemented.

The most significant UX problems are:
1. **Batch extraction fragility** — one failure loses everything (this is the single biggest UX issue)
2. **Premature password prompt** — shown without context before any file is selected
3. **Accessibility gap** in `FileRowView` — the remove button is hidden from VoiceOver users

Fixing these three items would substantially improve the user experience without requiring architectural changes.
