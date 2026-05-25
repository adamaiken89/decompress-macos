import Foundation
import Observation

@Observable
@MainActor
final class DecompressViewModel {
    var extractionState: ExtractionState = .idle
    var selectedURLs: [URL] = []
    var outputDirectoryURL: URL?
    var showFilePicker = false
    var autoExtractToSourceDir = true
    var deleteArchiveAfterExtraction = false

    private let service = DecompressionService.shared

    var isIdle: Bool {
        if case .idle = extractionState { return true }
        return false
    }

    var isBusy: Bool {
        !isIdle
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

    @MainActor
    func extractAll() {
        guard !selectedURLs.isEmpty else { return }
        extractionState = .preparing

        let urls = selectedURLs
        Task {
            for url in urls {
                await extractSingle(url)
            }
        }
    }

    @MainActor
    private func extractSingle(_ url: URL) async {
        guard let format = service.detectFormat(from: url) else {
            extractionState = .failed("Could not detect format for \(url.lastPathComponent)")
            return
        }

        let destination: URL
        if let customOutput = outputDirectoryURL {
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
                progressHandler: { [weak self] progress, file in
                    Task { @MainActor in
                        self?.extractionState = .extracting(progress: progress, currentFile: file)
                    }
                }
            )

            if deleteArchiveAfterExtraction {
                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }

            extractionState = .completed(result)
        } catch {
            extractionState = .failed(error.localizedDescription)
        }
    }

    @MainActor
    func reset() {
        extractionState = .idle
    }

    @MainActor
    func clearFiles() {
        selectedURLs.removeAll()
        extractionState = .idle
    }
}
