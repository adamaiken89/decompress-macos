import Foundation
import Observation
import OSLog

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
    var lastFailedSourceURL: URL?

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
        case .idle, .completed, .failed:
            false
        }
    }

    var canCancel: Bool {
        switch extractionState {
        case .preparing, .extracting:
            true
        case .idle, .completed, .failed:
            false
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

        let filtered = archiveURLs.filter { url in
            guard let info = splitPartInfo(for: url), info.partNumber > 1 else { return true }
            let allCandidateURLs = selectedURLs + archiveURLs
            return !allCandidateURLs.contains { candidate in
                guard candidate != url, let candidateInfo = splitPartInfo(for: candidate) else { return false }
                return candidateInfo.groupKey == info.groupKey && candidateInfo.partNumber == 1
            }
        }

        selectedURLs.append(contentsOf: filtered)
    }

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
            await performExtractions(
                urls: urls,
                useExtractInPlace: useExtractInPlace,
                useAutoDir: useAutoDir,
                useOutputDir: useOutputDir,
                usePassword: usePassword,
                shouldTrash: shouldTrash
            )
            extractionTask = nil
        }
    }

    private func destinationURL(
        for url: URL,
        extractInPlace: Bool,
        autoDir: Bool,
        outputDir: URL?
    ) -> URL {
        if extractInPlace {
            return url.deletingLastPathComponent()
        }
        if let customOutput = outputDir, !autoDir {
            return FileManager.default.uniqueDirectoryURL(
                in: customOutput,
                preferredName: url.deletingPathExtension().lastPathComponent
            )
        }
        return FileManager.default.suggestedDestinationURL(for: url)
    }

    private func performExtractions(
        urls: [URL],
        useExtractInPlace: Bool,
        useAutoDir: Bool,
        useOutputDir: URL?,
        usePassword: String?,
        shouldTrash: Bool
    ) async {
        let totalArchives = urls.count
        for (index, url) in urls.enumerated() {
            if Task.isCancelled { break }

            guard let format = service.detectFormat(from: url) else {
                lastFailedSourceURL = url
                extractionState = .failed("Could not detect format for \(url.lastPathComponent)")
                extractionTask = nil
                return
            }

            let destination = destinationURL(
                for: url,
                extractInPlace: useExtractInPlace,
                autoDir: useAutoDir,
                outputDir: useOutputDir
            )

            do {
                let result = try await service.extract(
                    sourceURL: url,
                    destinationURL: destination,
                    format: format,
                    password: usePassword,
                    progressHandler: { [weak self] progress, file in
                        Task { @MainActor in
                            self?.extractionState = .extracting(
                                progress: progress,
                                currentFile: file,
                                archiveIndex: index,
                                totalArchives: totalArchives
                            )
                        }
                    }
                )

                if shouldTrash {
                    try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
                }

                extractionState = .completed(result)
            } catch {
                Logger(subsystem: "com.decompress", category: "viewmodel")
                    .error("Extraction failed: \(url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                lastFailedSourceURL = url
                extractionState = .failed("\(url.lastPathComponent): \(error.localizedDescription)")
                extractionTask = nil
                return
            }
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
        lastFailedSourceURL = nil
    }
}
