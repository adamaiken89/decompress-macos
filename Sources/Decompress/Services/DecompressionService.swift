import Foundation

actor DecompressionService {
    enum ServiceError: Error, LocalizedError, Sendable {
        case unsupportedFormat(String)
        case fileNotFound(URL)
        case extractionFailed(String)
        case destinationCreationFailed(URL)
        case processError(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                "Unsupported archive format: \(ext)"

            case .fileNotFound(let url):
                "File not found: \(url.lastPathComponent)"

            case .extractionFailed(let reason):
                "Extraction failed: \(reason)"

            case .destinationCreationFailed(let url):
                "Could not create destination: \(url.path)"

            case .processError(let msg):
                "Process error: \(msg)"
            }
        }
    }

    static let shared = DecompressionService()
    private init() {}

    func extract(
        sourceURL: URL,
        destinationURL: URL,
        format: ArchiveFormat,
        progressHandler: @Sendable @escaping (Double, String) -> Void
    ) async throws -> ExtractionResult {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ServiceError.fileNotFound(sourceURL)
        }

        try createDestinationDirectory(at: destinationURL)
        progressHandler(0.1, "Preparing...")

        let startTime = Date()
        let sourceSize = (try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0

        switch format {
        case .zip:
            try await extractZip(source: sourceURL, dest: destinationURL, progress: progressHandler)

        case .tar, .tarGz, .tarBz2, .tarXz:
            try await extractTar(source: sourceURL, dest: destinationURL, format: format, progress: progressHandler)

        case .gzip:
            try await extractSingleFile(source: sourceURL, dest: destinationURL, tool: "gunzip", args: ["-f", sourceURL.path])

        case .bzip2:
            try await extractSingleFile(source: sourceURL, dest: destinationURL, tool: "bunzip2", args: ["-f", sourceURL.path])

        case .xz:
            try await extractSingleFile(source: sourceURL, dest: destinationURL, tool: "unxz", args: ["-f", sourceURL.path])

        case .sevenZip:
            try await extractWithUnar(source: sourceURL, dest: destinationURL, progress: progressHandler)

        case .rar:
            try await extractWithUnar(source: sourceURL, dest: destinationURL, progress: progressHandler)
        }

        let duration = Date().timeIntervalSince(startTime)
        let fileCount = countFilesRecursively(at: destinationURL)

        progressHandler(1.0, "Done")

        return ExtractionResult(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            format: format,
            fileCount: fileCount,
            duration: duration,
            bytesExtracted: sourceSize
        )
    }

    nonisolated func detectFormat(from url: URL) -> ArchiveFormat? {
        detectFormatByExtension(from: url) ?? detectFormatByMagicBytes(from: url)
    }

    nonisolated private func detectFormatByExtension(from url: URL) -> ArchiveFormat? {
        let path = url.path.lowercased()
        let sortedFormats = ArchiveFormat.allCases.sorted { lhs, rhs in
            let lhsLen = lhs.fileExtensions.map(\.count).max() ?? 0
            let rhsLen = rhs.fileExtensions.map(\.count).max() ?? 0
            return lhsLen > rhsLen
        }
        for format in sortedFormats {
            for ext in format.fileExtensions where path.hasSuffix(".\(ext)") {
                return format
            }
        }
        return nil
    }

    nonisolated private func detectFormatByMagicBytes(from url: URL) -> ArchiveFormat? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let headerData = handle.readData(ofLength: 16)
        guard headerData.count >= 4 else { return nil }

        for format in ArchiveFormat.allCases where !format.magicBytes.isEmpty {
            for magic in format.magicBytes where headerData.starts(with: magic) {
                return format
            }
        }
        return nil
    }

    private func createDestinationDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func extractZip(
        source: URL,
        dest: URL,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        progress(0.2, "Extracting ZIP...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", source.path, dest.path]

        try await runProcess(process, progress: progress)
    }

    private func extractTar(
        source: URL,
        dest: URL,
        format: ArchiveFormat,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        progress(0.2, "Extracting TAR...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")

        switch format {
        case .tarGz:
            process.arguments = ["-xzf", source.path, "-C", dest.path]

        case .tarBz2:
            process.arguments = ["-xjf", source.path, "-C", dest.path]

        case .tarXz:
            process.arguments = ["-xJf", source.path, "-C", dest.path]

        default:
            process.arguments = ["-xf", source.path, "-C", dest.path]
        }

        try await runProcess(process, progress: progress)
    }

    private func extractSingleFile(
        source: URL,
        dest: URL,
        tool: String,
        args: [String]
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/\(tool)")
        process.arguments = args

        try await runProcess(process, progress: { _, _ in })
    }

    private func extractWithUnar(
        source: URL,
        dest: URL,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        progress(0.2, "Extracting (unar)...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unar")
        process.arguments = ["-o", dest.path, "-q", source.path]

        try await runProcess(process, progress: progress)
    }

    private func runProcess(
        _ process: Process,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorMsg = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(
                        throwing: ServiceError.processError(
                            errorMsg.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ServiceError.processError(error.localizedDescription))
            }
        }
    }

    private func countFilesRecursively(at url: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil
        ) else { return 0 }
        var count = 0
        while enumerator.nextObject() != nil {
            count += 1
        }
        return count
    }
}
