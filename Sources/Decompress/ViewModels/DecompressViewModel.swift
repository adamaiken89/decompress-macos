import Foundation
import Observation

@Observable
@MainActor
final class DecompressViewModel {
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

    private let service = DecompressionService.shared
    private var extractionTask: Task<Void, Never>?

    var isIdle: Bool {
        if case .idle = extractionState { return true }
        return false
    }

    var isBusy: Bool {
        switch extractionState {
        case .preparing, .extracting: true
        case .idle, .completed, .failed: false
        }
    }

    var canCancel: Bool {
        switch extractionState {
        case .preparing, .extracting: true
        case .idle, .completed, .failed: false
        }
    }

    func cancelExtraction() {
        extractionTask?.cancel()
        extractionTask = nil
        extractionState = .idle
    }

    @MainActor
    func addFiles(_ urls: [URL]) {
        let archiveURLs = urls.filter { url in
            let format = ArchiveFormat.allCases.first { format in
                format.fileExtensions.contains { ext in
                    url.lastPathComponent.lowercased().hasSuffix(".\(ext)") ||
                    url.lastPathComponent.lowercased().contains(".\(ext)")
                }
            }
            return format != nil
        }
        selectedURLs.append(contentsOf: archiveURLs)
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

    @MainActor
    func extractAll() {
        guard !selectedURLs.isEmpty else { return }

        let urls = selectedURLs
        let useExtractInPlace = extractInPlace
        let useAutoDir = autoExtractToSourceDir
        let useOutputDir = outputDirectoryURL
        let usePassword = isPasswordProtected && !password.isEmpty ? password : nil
        let shouldTrash = deleteArchiveAfterExtraction

        extractionTask = Task {
            extractionState = .preparing

            for url in urls {
                if Task.isCancelled { break }

                guard let format = service.detectFormat(from: url) else {
                    extractionState = .failed("Could not detect format for \(url.lastPathComponent)")
                    extractionTask = nil
                    return
                }

                let destination: URL
                if useExtractInPlace {
                    destination = url.deletingLastPathComponent()
                } else if let customOutput = useOutputDir, !useAutoDir {
                    destination = FileManager.default.uniqueDirectoryURL(
                        in: customOutput,
                        preferredName: url.deletingPathExtension().lastPathComponent
                    )
                } else {
                    destination = FileManager.default.suggestedDestinationURL(for: url)
                }

                do {
                    let result = try await service.extract(
                        sourceURL: url,
                        destinationURL: destination,
                        format: format,
                        password: usePassword,
                        progressHandler: { [weak self] progress, file in
                            Task { @MainActor in
                                self?.extractionState = .extracting(progress: progress, currentFile: file)
                            }
                        }
                    )

                    if shouldTrash {
                        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    }

                    extractionState = .completed(result)
                } catch {
                    extractionState = .failed("\(url.lastPathComponent): \(error.localizedDescription)")
                    extractionTask = nil
                    return
                }
            }

            extractionTask = nil
        }
    }

    @MainActor
    func reset() {
        extractionState = .idle
    }

    @MainActor
    func removeFile(at index: Int) {
        guard index >= 0, index < selectedURLs.count else { return }
        selectedURLs.remove(at: index)
        if selectedURLs.isEmpty {
            extractionState = .idle
            password = ""
            isPasswordProtected = false
        }
    }

    @MainActor
    func clearFiles() {
        selectedURLs.removeAll()
        extractionState = .idle
        password = ""
        isPasswordProtected = false
    }
}
