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

  var extractionState: ExtractionState = .idle
  var selectedURLs: [URL] = []
  var outputDirectoryURL: URL?
  var showFilePicker = false
  var showHelp = false
  var autoExtractToSourceDir = true
  var deleteArchiveAfterExtraction = false
  var isPasswordProtected = false
  var password = ""
  var extractInPlace = false
  var extractionStartTime: Date?
  var lastFailedSourceURL: URL?
  var archiveContents: [ArchiveContent] = []
  var pendingQueue: [[URL]] = []
  var launchMode: LaunchMode = .standard

  var queueCount: Int { pendingQueue.count }

  private let service = DecompressionService.shared
  private var extractionTask: Task<Void, Never>?

  var isIdle: Bool {
    if case .idle = extractionState { return true }
    return false
  }

  var isBusy: Bool {
    switch extractionState {
    case .preparing, .extracting:
      true

    case .idle, .browsing, .completed, .failed:
      false
    }
  }

  var canCancel: Bool {
    switch extractionState {
    case .preparing, .extracting:
      true

    case .idle, .browsing, .completed, .failed:
      false
    }
  }

  func cancelExtraction() {
    extractionTask?.cancel()
    extractionTask = nil
    extractionState = .idle
    extractionStartTime = nil
    processNextInQueue()
  }

  func addFiles(_ urls: [URL]) {
    let archiveURLs = urls.filter { url in
      let format = ArchiveFormat.allCases.first { format in
        format.fileExtensions.contains { ext in
          url.lastPathComponent.lowercased().hasSuffix(".\(ext)")
            || url.lastPathComponent.lowercased().contains(".\(ext)")
        }
      }
      return format != nil
    }

    let filtered = archiveURLs.filter { url in
      guard let info = splitPartInfo(for: url), info.partNumber > 1 else { return true }
      let allCandidateURLs = selectedURLs + archiveURLs
      return !allCandidateURLs.contains { candidate in
        guard candidate != url, let candidateInfo = splitPartInfo(for: candidate) else {
          return false
        }
        return candidateInfo.groupKey == info.groupKey && candidateInfo.partNumber == 1
      }
    }

    selectedURLs.append(contentsOf: filtered)
  }

  func detectFormat(for url: URL) -> ArchiveFormat? {
    service.detectFormat(from: url)
  }

  func checkForEncryptedArchives(_ urls: [URL]) {
    for url in urls where service.isZipEncrypted(url) {
      isPasswordProtected = true
      return
    }
  }

  func previewArchives() {
    guard !selectedURLs.isEmpty else { return }

    extractionTask?.cancel()

    let urls = selectedURLs
    extractionState = .preparing
    extractionTask = Task {
      var contents: [ArchiveContent] = []
      for url in urls {
        if Task.isCancelled { break }
        let format = service.detectFormat(from: url)
        guard let format else {
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
        extractionState = .idle
        extractionTask = nil
        return
      }
      archiveContents = contents
      extractionState = .browsing
      extractionTask = nil
    }
  }

  func backToFiles() {
    extractionTask?.cancel()
    extractionTask = nil
    extractionState = .idle
    archiveContents = []
  }

  func extractAll(selectedEntries: [URL: Set<String>]? = nil) {
    guard !selectedURLs.isEmpty else { return }

    let urls = selectedURLs
    let useExtractInPlace = extractInPlace
    let useAutoDir = autoExtractToSourceDir
    let useOutputDir = outputDirectoryURL
    let usePassword = isPasswordProtected && !password.isEmpty ? password : nil
    let shouldTrash = deleteArchiveAfterExtraction
    let useSelectedEntries = selectedEntries

    extractionStartTime = Date()
    extractionState = .preparing
    extractionTask = Task {
      try? await Task.sleep(for: .seconds(0.5))
      if Task.isCancelled {
        extractionState = .idle
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
        selectedEntries: useSelectedEntries
      )
      handleExtractionCompletion(result)
    }
  }

  func openFiles(_ urls: [URL]) {
    launchMode = .fileOpen
    switch extractionState {
    case .preparing, .extracting:
      pendingQueue.append(urls)
      return
    default:
      break
    }
    beginProcessing(urls)
  }

  private func beginProcessing(_ urls: [URL]) {
    extractionTask?.cancel()
    extractionTask = nil
    clearFiles()
    addFiles(urls)
    checkForEncryptedArchives(urls)
    if !isPasswordProtected {
      extractAll()
    }
  }

  private func processNextInQueue() {
    guard !pendingQueue.isEmpty else { return }
    let next = pendingQueue.removeFirst()
    beginProcessing(next)
  }

  private func handleExtractionCompletion(_ result: BatchResult) {
    extractionTask = nil
    if !pendingQueue.isEmpty {
      processNextInQueue()
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
      extractionState = .completed(result)
    }
  }

  func clearQueue() {
    pendingQueue.removeAll()
  }

  func reset() {
    launchMode = .standard
    extractionState = .idle
    extractionStartTime = nil
    archiveContents = []
  }

  func removeFile(at index: Int) {
    guard index >= 0, index < selectedURLs.count else { return }
    selectedURLs.remove(at: index)
    if selectedURLs.isEmpty {
      extractionState = .idle
      password = ""
      isPasswordProtected = false
      archiveContents = []
    }
  }

  func clearFiles() {
    selectedURLs.removeAll()
    extractionState = .idle
    password = ""
    isPasswordProtected = false
    extractionStartTime = nil
    lastFailedSourceURL = nil
    archiveContents = []
  }
}

// MARK: - Archive helpers

extension DecompressViewModel {
  private func splitPartInfo(for url: URL) -> (groupKey: String, partNumber: Int)? {
    let name = url.lastPathComponent

    if let match = try? /^(.+)\.part(\d+)\./.firstMatch(in: name) {
      return (String(match.1), Int(match.2) ?? 0)
    }

    if let match = try? /^(.+)\.(7z|zip)\.(\d{3})$/.firstMatch(in: name) {
      return (String(match.1), Int(match.3) ?? 0)
    }

    if let match = try? /^(.+)\.r(\d{2})$/.firstMatch(in: name) {
      return (String(match.1), Int(match.2) ?? 0)
    }

    if let match = try? /^(.+)\.(\d{3})$/.firstMatch(in: name) {
      return (String(match.1), Int(match.2) ?? 0)
    }

    return nil
  }
}

// MARK: - Extraction

extension DecompressViewModel {
  private func performExtractions(
    urls: [URL],
    destinationFor: (URL) -> URL,
    usePassword: String?,
    shouldTrash: Bool,
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
            error: String(format: loc("Could not detect format for %@"), url.lastPathComponent)
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
          progressHandler: makeProgressHandler(index: index, totalArchives: totalArchives)
        )

        if shouldTrash {
          try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }

        successes.append(result)
      } catch {
        Logger(subsystem: "com.decompress", category: "viewmodel")
          .error(
            "Extraction failed: \(url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
          )
        failures.append(
          BatchResult.Failure(
            sourceURL: url,
            error: error.localizedDescription
          ))
      }
    }

    lastFailedSourceURL = failures.last?.sourceURL
    return BatchResult(successes: successes, failures: failures)
  }

  private func makeProgressHandler(
    index: Int,
    totalArchives: Int
  ) -> @Sendable (Double, String) -> Void {
    { [weak self] progress, file in
      Task { @MainActor in
        self?.extractionState = .extracting(
          progress: progress,
          currentFile: file,
          archiveIndex: index,
          totalArchives: totalArchives
        )
      }
    }
  }
}
