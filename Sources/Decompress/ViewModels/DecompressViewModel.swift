import AppKit
import Foundation
import OSLog
import Observation

enum LaunchMode {
  case standard
  case fileOpen
}

@Observable
@MainActor
final class DecompressViewModel {
  static let shared = DecompressViewModel()

  private(set) var phase: ExtractionPhase = .idle
  private(set) var batch = BatchSession()
  private(set) var queue = ExtractionQueue()
  var password = PasswordState()
  var settings = AppSettings.load() {
    didSet { settings.save() }
  }
  var launchMode: LaunchMode = .standard
  var extractInPlace = false
  var showFilePicker = false
  var showHelp = false

  var selectedURLs: [URL] { batch.urls }
  var archiveContents: [ArchiveContent] { batch.contents }
  var detectedFormats: [URL: ArchiveFormat] { batch.formats }
  var lastBatchResult: BatchResult? { batch.lastResult }
  var lastFailedSourceURL: URL? { batch.lastFailedSourceURL }
  var extractionStartTime: Date? { batch.extractionStartTime }
  var queueCount: Int { queue.count }

  let service: DecompressionService
  private var extractionTask: Task<Void, Never>?

  init(service: DecompressionService = .shared) {
    self.service = service
  }

  var isIdle: Bool {
    if case .idle = phase { return true }
    return false
  }

  var isBusy: Bool { phase.isBusy }
  var canCancel: Bool { phase.canCancel }

  func cancelExtraction() {
    extractionTask?.cancel()
    extractionTask = nil
    Task {
      await service.cancelRunningProcesses()
    }
    phase = .idle
    batch.clearStartTime()
    processNextInQueue()
  }

  func addFiles(_ urls: [URL]) {
    batch.add(urls)
  }

  @discardableResult
  func detectFormat(for url: URL) -> ArchiveFormat? {
    let format = service.detectFormat(from: url)
    if let format {
      batch.record(format: format, for: url)
    }
    return format
  }

  func checkForEncryptedArchives(_ urls: [URL]) {
    for url in urls {
      guard let format = ArchiveFormatDetector.detectFormat(from: url) else { continue }
      if ArchiveFormatDetector.isEncrypted(url: url, format: format) == true {
        password.isProtected = true
        return
      }
    }
  }

  func previewArchives() {
    guard !batch.isEmpty else { return }

    extractionTask?.cancel()

    let urls = batch.urls
    phase = .preparing(totalArchives: urls.count)
    extractionTask = Task {
      var contents: [ArchiveContent] = []
      for url in urls {
        if Task.isCancelled { break }
        guard let format = service.detectFormat(from: url) else {
          contents.append(
            ArchiveContent(
              sourceURL: url,
              format: .zip,
              entries: [],
              listError: String(
                format: loc("Could not detect format for %@"), url.lastPathComponent)
            ))
          continue
        }
        do {
          let entries = try await service.listContents(of: url, format: format)
          contents.append(ArchiveContent(sourceURL: url, format: format, entries: entries))
        } catch {
          Logger(subsystem: "com.decompress", category: "viewmodel")
            .error(
              "Failed to list contents: \(url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
          contents.append(
            ArchiveContent(
              sourceURL: url,
              format: format,
              entries: [],
              listError: error.localizedDescription
            ))
        }
      }
      if Task.isCancelled {
        phase = .idle
        extractionTask = nil
        return
      }
      batch.setContents(contents)
      phase = .browsing
      extractionTask = nil
    }
  }

  func backToFiles() {
    extractionTask?.cancel()
    extractionTask = nil
    phase = .idle
    batch.clearContents()
  }

  func extractAll(selectedEntries: [URL: Set<String>]? = nil) {
    startExtraction(urls: selectedURLs, selectedEntries: selectedEntries)
  }

  func retryFailures() {
    guard let result = lastBatchResult, !result.failures.isEmpty else { return }
    if result.hasPasswordFailuresOnly, password.isProtected, password.value.isEmpty { return }
    startExtraction(urls: result.failures.map(\.sourceURL), selectedEntries: nil)
  }

  private func startExtraction(urls: [URL], selectedEntries: [URL: Set<String>]?) {
    guard !urls.isEmpty else { return }

    let useExtractInPlace = extractInPlace
    let useAutoDir = settings.autoExtractToSourceDir
    let useOutputDir = settings.outputDirectoryURL
    let usePassword = password.effectivePassword()
    let shouldTrash = settings.deleteArchiveAfterExtraction
    let useSelectedEntries = selectedEntries

    password.error = nil
    batch.markStarted()
    phase = .preparing(totalArchives: urls.count)
    extractionTask = Task {
      try? await Task.sleep(for: .seconds(0.5))
      if Task.isCancelled {
        phase = .idle
        extractionTask = nil
        return
      }

      let destinationFor: (URL) -> URL = { url in
        if useExtractInPlace {
          return url.deletingLastPathComponent()
        }
        if let customOutput = useOutputDir, !useAutoDir {
          return FileManager.default.uniqueDirectoryURL(
            in: customOutput,
            preferredName: url.deletingPathExtension().lastPathComponent
          )
        }
        return FileManager.default.suggestedDestinationURL(for: url)
      }
      let result = await performExtractions(
        urls: urls,
        destinationFor: destinationFor,
        usePassword: usePassword,
        shouldTrash: shouldTrash,
        allowNonEmptyDestination: useExtractInPlace,
        selectedEntries: useSelectedEntries
      )
      handleExtractionCompletion(result)
    }
  }

  func openFiles(_ urls: [URL]) {
    launchMode = .fileOpen
    if phase.isBusy {
      queue.enqueue(urls)
      return
    }
    beginProcessing(urls)
  }

  private func beginProcessing(_ urls: [URL]) {
    extractionTask?.cancel()
    extractionTask = nil
    clearFiles()
    addFiles(urls)
    checkForEncryptedArchives(urls)
    if !password.isProtected {
      extractAll()
    }
  }

  private func processNextInQueue() {
    guard let next = queue.popNext() else { return }
    beginProcessing(next)
  }

  private func handleExtractionCompletion(_ result: BatchResult) {
    extractionTask = nil
    batch.recordResult(result)

    if !queue.isEmpty {
      processNextInQueue()
      return
    }

    if result.hasPasswordFailuresOnly {
      password = PasswordState(
        isProtected: true, value: "", error: loc("Incorrect password. Try again."))
      phase = .idle
      return
    }

    if case .fileOpen = launchMode, result.allSucceeded {
      launchMode = .standard
      if let firstSuccess = result.successes.first {
        NSWorkspace.shared.selectFile(
          firstSuccess.destinationURL.path,
          inFileViewerRootedAtPath: firstSuccess.destinationURL
            .deletingLastPathComponent().path
        )
      }
      Task {
        try? await Task.sleep(for: .seconds(0.5))
        NSApplication.shared.terminate(nil)
      }
    } else {
      phase = .completed(result)
    }
  }

  func clearQueue() {
    queue.removeAll()
  }

  func reset() {
    launchMode = .standard
    phase = .idle
    batch.clearContents()
    batch.clearStartTime()
  }

  func removeFile(at index: Int) {
    let becameEmpty = batch.remove(at: index)
    if becameEmpty {
      phase = .idle
      batch.reset()
      password.clear()
    }
  }

  func clearFiles() {
    phase = .idle
    batch.reset()
    password.clear()
  }
}

// MARK: - Extraction

extension DecompressViewModel {
  private func performExtractions(
    urls: [URL],
    destinationFor: (URL) -> URL,
    usePassword: String?,
    shouldTrash: Bool,
    allowNonEmptyDestination: Bool,
    selectedEntries: [URL: Set<String>]? = nil
  ) async -> BatchResult {
    let totalArchives = urls.count
    var successes: [ExtractionResult] = []
    var failures: [BatchResult.Failure] = []

    for (index, url) in urls.enumerated() where !Task.isCancelled {
      guard let format = service.detectFormat(from: url) else {
        failures.append(
          BatchResult.Failure(
            sourceURL: url,
            error: String(format: loc("Could not detect format for %@"), url.lastPathComponent),
            isPasswordError: false
          ))
        continue
      }

      let destination = destinationFor(url)
      let entriesForURL: [String]? = selectedEntries?[url].map { Array($0) }

      do {
        let result = try await service.extract(
          sourceURL: url,
          destinationURL: destination,
          format: format,
          password: usePassword,
          selectedEntries: entriesForURL,
          allowNonEmptyDestination: allowNonEmptyDestination,
          progressHandler: makeProgressHandler(index: index, totalArchives: totalArchives)
        )

        if shouldTrash {
          try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }

        successes.append(result)
      } catch let error as ServiceError {
        Logger(subsystem: "com.decompress", category: "viewmodel")
          .error(
            "Extraction failed: \(url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
          )
        var isPasswordError = false
        if case .wrongPassword = error { isPasswordError = true }
        failures.append(
          BatchResult.Failure(
            sourceURL: url,
            error: error.localizedDescription,
            isPasswordError: isPasswordError
          ))
      } catch {
        Logger(subsystem: "com.decompress", category: "viewmodel")
          .error(
            "Extraction failed: \(url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
          )
        failures.append(
          BatchResult.Failure(
            sourceURL: url,
            error: error.localizedDescription,
            isPasswordError: false
          ))
      }
    }

    return BatchResult(successes: successes, failures: failures)
  }

  private func makeProgressHandler(
    index: Int,
    totalArchives: Int
  ) -> @Sendable (Double, String) -> Void {
    { [weak self] progress, file in
      Task { @MainActor in
        self?.phase = .extracting(
          progress: progress,
          currentFile: file,
          archiveIndex: index,
          totalArchives: totalArchives
        )
      }
    }
  }
}
