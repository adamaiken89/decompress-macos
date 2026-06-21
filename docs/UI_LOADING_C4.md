# Decompress — UI Loading Sequence (C4 Diagrams)

## Level 1: System Context

```mermaid
C4Context
  title Decompress — System Context

  Person(user, "macOS User", "Interacts via drag-drop, file picker, or double-click")
  System(decompress, "Decompress", "macOS archive extraction utility")
  System_Ext(fs, "File System", "Source archives, extraction destinations")
  System_Ext(tools, "System Tools", "ditto, tar, gunzip, bunzip2, unxz, unzip, unar")

  Rel(user, decompress, "Opens archives via drag-drop or double-click")
  Rel(decompress, fs, "Reads archives, writes extracted files")
  Rel(decompress, tools, "Invokes for extraction")
```

## Level 2: Container Diagram

```mermaid
C4Container
  title Decompress — Container Diagram

  Container(app, "DecompressApp", "SwiftUI App", "Entry point, scene lifecycle")
  Container(vm, "DecompressViewModel", "@Observable @MainActor", "State machine, orchestration")
  Container(contentView, "ContentView", "SwiftUI View", "Root view switch: lite vs full")
  Container(liteView, "LiteContentView", "SwiftUI View", "Minimal UI for file-open launches")
  Container(fullView, "Full Content Views", "SwiftUI Views", "DragDropView, ArchiveContentView, etc.")
  Container(service, "DecompressionService", "Actor", "Format detection, extraction, process runner")

  Rel(app, contentView, "Renders", ".environment(viewModel)")
  Rel(contentView, liteView, "If launchedByFileOpen == true")
  Rel(contentView, fullView, "If launchedByFileOpen == false")
  Rel(vm, service, "Calls", "detectFormat, extract, listContents")
  Rel(fullView, vm, "Reads state", "extractionState, selectedURLs, etc.")
  Rel(liteView, vm, "Reads state", "extractionState, isPasswordProtected")
```

## Level 3: Component Diagram — App Entry

```mermaid
C4Component
  title DecompressApp — Entry Point

  Container_Ext(appDelegate, "AppDelegate", "Handles open urls from Finder")

  Container(decompressApp, "DecompressApp", "@main struct", "WindowGroup + Help window + Settings")
  Container(viewModel, "DecompressViewModel.shared", "Singleton", "Holds all state")
  Container(contentView, "ContentView", "Root view", "Branches on launchedByFileOpen")
  Container(helpView, "HelpView", "Separate window", "Usage guide")
  Container(settingsView, "SettingsView", "Settings window", "Preferences")

  Rel(decompressApp, contentView, "Creates", ".environment(viewModel)")
  Rel(decompressApp, viewModel, "Initializes", "@State private var viewModel")
  Rel(appDelegate, viewModel, "Calls openFiles(_:)", "Sets launchedByFileOpen = true")
  Rel(contentView, helpView, "Opens via openWindow(id: 'help')", "on showHelp")
```

## Level 3: Component Diagram — ContentView Branching

```mermaid
C4Component
  title ContentView — State Machine Router

  Container_Ext(viewModel, "DecompressViewModel", "State holder")

  Container(contentView, "ContentView", "Root view", "Switch on extractionState + launchedByFileOpen")
  Container(liteView, "LiteContentView", "Lite mode", "For double-click launches")
  Container(dragDrop, "DragDropView", "idle state", "Drop zone + file list + controls")
  Container(progress, "ExtractionProgressView", "preparing / extracting", "Spinner + progress bar")
  Container(browse, "ArchiveContentView", "browsing", "Per-file checkbox selection")
  Container(completed, "ExtractionCompletedView", "completed", "Results + reveal in Finder")
  Container(failed, "ExtractionFailedView", "failed", "Error message + retry")

  Rel(contentView, liteView, "launchedByFileOpen == true", "Fixed size, centered")
  Rel(contentView, dragDrop, "extractionState == .idle", "Full mode only")
  Rel(contentView, progress, "extractionState == .preparing | .extracting", "")
  Rel(contentView, browse, "extractionState == .browsing", "")
  Rel(contentView, completed, "extractionState == .completed", "Receives BatchResult")
  Rel(contentView, failed, "extractionState == .failed", "Receives error message")
```

## Level 3: Component Diagram — LiteContentView

```mermaid
C4Component
  title LiteContentView — File-Open Launch UI

  Container_Ext(viewModel, "DecompressViewModel", "launchedByFileOpen = true")

  Container(liteView, "LiteContentView", "SwiftUI View", "Minimal extraction UI")
  Container(passwordView, "litePasswordView", "Password prompt", "If isPasswordProtected")
  Container(preparingView, "litePreparingView", "Spinner", "Auto-extracting")
  Container(progressView, "liteProgressView", "Progress bar", "During extraction")
  Container(completedView, "liteCompletedView", "Status + auto-quit", "On success: Finder + quit")
  Container(failedView, "liteFailedView", "Error + retry", "On failure: show + stay")

  Rel(liteView, passwordView, "idle + isPasswordProtected", "User enters password, clicks Extract")
  Rel(liteView, preparingView, "idle + !isPasswordProtected", "Auto-extract immediately")
  Rel(liteView, progressView, "preparing | extracting | browsing", "")
  Rel(liteView, completedView, "completed", "allSucceeded → auto-quit after 0.5s")
  Rel(liteView, failedView, "failed", "Stays open, shows error")
  Rel(liteView, viewModel, "resizeWindowForLiteMode()", "Shrinks to fit content")
```

## Level 3: Component Diagram — Full Mode Views

```mermaid
C4Component
  title Full Mode — DragDropView Component Breakdown

  Container_Ext(viewModel, "DecompressViewModel", "State holder")

  Container(dragDrop, "DragDropView", "idle state", "Main interaction view")
  Container(dropZone, "dropZone", "Empty state", "Large drop area with format hints")
  Container(compactBar, "compactDropBar", "Has files", "Drop more or click to add")
  Container(fileList, "selectedFilesSection", "File list", "ScrollView with FileRowView per file")
  Container(controls, "bottomControls", "Actions", "Extract in place, Preview, Extract All, Clear")
  Container(passwordPrompt, "PasswordPromptView", "Conditional", "If isPasswordProtected")

  Rel(dragDrop, dropZone, "selectedURLs.isEmpty", "")
  Rel(dragDrop, compactBar, "Has files", "Top bar")
  Rel(dragDrop, fileList, "Has files", "Scrollable file list")
  Rel(dragDrop, controls, "Has files", "Bottom action bar")
  Rel(controls, passwordPrompt, "isPasswordProtected", "Password field + Extract button")
  Rel(dragDrop, viewModel, "addFiles, extractAll, previewArchives", "")
```

## Extraction State Machine

```mermaid
stateDiagram-v2
  [*] --> idle

  idle --> browsing : previewArchives()
  idle --> preparing : extractAll()

  preparing --> extracting : progress starts
  preparing --> idle : cancelled

  extracting --> completed : success
  extracting --> failed : error
  extracting --> idle : cancelled

  browsing --> preparing : extractAll(selectedEntries)
  browsing --> idle : backToFiles()

  completed --> idle : reset()
  failed --> idle : reset()

  note right of idle
    DragDropView (full)
    litePreparingView (lite)
  end note

  note right of preparing
    ExtractionProgressView
    liteProgressView
  end note

  note right of extracting
    ExtractionProgressView (with progress)
    liteProgressView (with progress)
  end note

  note right of browsing
    ArchiveContentView
    liteProgressView
  end note

  note right of completed
    ExtractionCompletedView
    liteCompletedView
  end note

  note right of failed
    ExtractionFailedView
    liteFailedView
  end note
```

## View Loading Sequence — Full Mode

```mermaid
sequenceDiagram
  participant User
  participant App as DecompressApp
  participant VM as DecompressViewModel
  participant CV as ContentView
  participant DDV as DragDropView
  participant PAV as ArchiveContentView
  participant EPV as ExtractionProgressView
  participant ECV as ExtractionCompletedView

  User->>App: Launch app
  App->>VM: Create shared singleton
  App->>CV: Create ContentView (.environment(vm))
  CV->>CV: extractionState == .idle, launchedByFileOpen == false
  CV->>DDV: Render DragDropView

  User->>DDV: Drop archive / Select files
  DDV->>VM: addFiles(urls)
  DDV->>VM: checkForEncryptedArchives(urls)

  alt Encrypted archive
    DDV->>DDV: Show PasswordPromptView
    User->>DDV: Enter password + Click Extract
    DDV->>VM: extractAll()
  else Plain archive
    User->>DDV: Click Extract All
    DDV->>VM: extractAll()
  end

  VM->>VM: extractionState = .preparing
  VM->>CV: State changed
  CV->>EPV: Render ExtractionProgressView

  VM->>VM: extractionState = .extracting(progress, file)
  VM->>CV: State changed
  CV->>EPV: Update progress bar + file name

  VM->>VM: extractionState = .completed(result)
  VM->>CV: State changed
  CV->>ECV: Render ExtractionCompletedView(result)

  User->>ECV: Click Reveal in Finder
  ECV->>ECV: NSWorkspace.shared.selectFile()
```

## View Loading Sequence — Lite Mode (Double-Click)

```mermaid
sequenceDiagram
  participant User
  participant Finder as Finder
  participant App as AppDelegate
  participant VM as DecompressViewModel
  participant CV as ContentView
  participant LCV as LiteContentView
  participant Service as DecompressionService

  User->>Finder: Double-click archive
  Finder->>App: application(_:open urls:)
  App->>VM: openFiles(urls)
  VM->>VM: launchedByFileOpen = true
  VM->>VM: beginProcessing(urls)

  alt Password protected
    VM->>VM: isPasswordProtected = true
    VM->>CV: State changed
    CV->>LCV: Render LiteContentView (litePasswordView)
    User->>LCV: Enter password
    User->>LCV: Click Extract
    LCV->>VM: extractAll()
  else Plain archive
    VM->>VM: extractAll() immediately
  end

  VM->>VM: extractionState = .preparing
  VM->>CV: State changed
  CV->>LCV: Render liteProgressView

  VM->>Service: extract(sourceURL, format, ...)
  Service->>VM: progress callback
  VM->>CV: extractionState = .extracting
  CV->>LCV: Update progress bar

  Service->>VM: extraction complete
  VM->>VM: extractionState = .completed(result)

  alt allSucceeded
    VM->>VM: launchedByFileOpen = false
    VM->>VM: NSWorkspace selectFile (reveal in Finder)
    VM->>VM: Task.sleep(0.5) → NSApp.terminate
  else Any failure
    VM->>VM: extractionState = .completed(result)
    VM->>CV: State changed
    CV->>LCV: Render liteCompletedView (shows error)
    Note over LCV: Stays open, user clicks Try Again
  end
```

## State → View Mapping Summary

| State | Full Mode View | Lite Mode View |
|-------|---------------|----------------|
| `.idle` | `DragDropView` | `litePasswordView` (encrypted) / `litePreparingView` (plain) |
| `.preparing` | `ExtractionProgressView` (spinner) | `liteProgressView` (spinner) |
| `.extracting` | `ExtractionProgressView` (progress bar) | `liteProgressView` (progress bar) |
| `.browsing` | `ArchiveContentView` | `liteProgressView` (fallback) |
| `.completed` | `ExtractionCompletedView` | `liteCompletedView` (auto-quit on success) |
| `.failed` | `ExtractionFailedView` | `liteFailedView` (stays open) |

## Launch Path Decision

```
App Launch
  ├── launchedByFileOpen == false → Full Mode (DragDropView)
  │     └── User drops/selects files
  │           ├── Encrypted → PasswordPromptView → extractAll()
  │           └── Plain → Extract All button → extractAll()
  │
  └── launchedByFileOpen == true → Lite Mode (LiteContentView)
        ├── Encrypted → litePasswordView → Enter password → extractAll()
        └── Plain → Auto extractAll() immediately
              ├── Success → auto-quit after 0.5s
              └── Failure → liteCompletedView (stays open)
```
