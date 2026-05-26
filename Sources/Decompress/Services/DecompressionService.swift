import Foundation
import OSLog

actor DecompressionService {
    private static let logger = Logger(subsystem: "com.decompress", category: "service")

    static let shared = DecompressionService()
    private init() {}

    nonisolated func detectFormat(from url: URL) -> ArchiveFormat? {
        let result = ArchiveFormatDetector.detectFormat(from: url)
        Self.logger.debug("Detect format: \(url.lastPathComponent, privacy: .public) -> \(result?.rawValue ?? "nil", privacy: .public)")
        return result
    }

    nonisolated func isZipEncrypted(_ url: URL) -> Bool {
        let result = ArchiveFormatDetector.isZipEncrypted(url)
        Self.logger.debug("ZIP encrypted check: \(url.lastPathComponent, privacy: .public) -> \(result)")
        return result
    }

    static func findTool(_ name: String) -> URL? {
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    func extract(
        sourceURL: URL,
        destinationURL: URL,
        format: ArchiveFormat,
        password: String? = nil,
        progressHandler: @Sendable @escaping (Double, String) -> Void
    ) async throws -> ExtractionResult {
        Self.logger.debug("Extract start: \(sourceURL.lastPathComponent, privacy: .public) format=\(format.rawValue, privacy: .public) dest=\(destinationURL.path, privacy: .public) hasPassword=\(password != nil, privacy: .public)")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            Self.logger.error("File not found: \(sourceURL.path, privacy: .public)")
            throw ServiceError.fileNotFound(sourceURL)
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        progressHandler(0.1, "Preparing...")

        let startTime = Date()
        let sourceSize = (try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64) ?? 0

        switch format {
        case .zip:
            if let password, !password.isEmpty {
                try await extractZipWithPassword(source: sourceURL, dest: destinationURL, password: password, progress: progressHandler)
            } else {
                try await extractZip(source: sourceURL, dest: destinationURL, progress: progressHandler)
            }

        case .tar, .tarGz, .tarBz2, .tarXz:
            try await extractTar(source: sourceURL, dest: destinationURL, format: format, progress: progressHandler)

        case .gzip:
            try await extractSingleFile(source: sourceURL, dest: destinationURL, tool: "gunzip", args: ["-f", sourceURL.path])

        case .bzip2:
            try await extractSingleFile(source: sourceURL, dest: destinationURL, tool: "bunzip2", args: ["-f", sourceURL.path])

        case .xz:
            try await extractSingleFile(source: sourceURL, dest: destinationURL, tool: "unxz", args: ["-f", sourceURL.path])

        case .sevenZip, .rar, .split:
            if let password, !password.isEmpty {
                try await extractWithUnar(source: sourceURL, dest: destinationURL, password: password, progress: progressHandler)
            } else {
                try await extractWithUnar(source: sourceURL, dest: destinationURL, progress: progressHandler)
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        let fileCount = FileManager.default.countFilesRecursively(at: destinationURL)

        Self.logger.debug("Extract success: \(sourceURL.lastPathComponent, privacy: .public) files=\(fileCount) duration=\(duration, format: .fixed(precision: 2))s")
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

    private func extractZip(
        source: URL,
        dest: URL,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        guard let toolURL = Self.findTool("ditto") else {
            throw ServiceError.toolNotFound("ditto")
        }
        progress(0.2, "Extracting ZIP...")
        let process = Process()
        process.executableURL = toolURL
        process.arguments = ["-x", "-k", source.path, dest.path]
        try await runProcess(process, progress: progress)
    }

    private func extractZipWithPassword(
        source: URL,
        dest: URL,
        password: String,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        guard let toolURL = Self.findTool("unzip") else {
            throw ServiceError.toolNotFound("unzip")
        }
        progress(0.2, "Extracting encrypted ZIP...")
        let process = Process()
        process.executableURL = toolURL
        process.arguments = ["-P", password, "-o", source.path, "-d", dest.path]
        try await runProcess(process, progress: progress)
    }

    private func extractTar(
        source: URL,
        dest: URL,
        format: ArchiveFormat,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        guard let toolURL = Self.findTool("tar") else {
            throw ServiceError.toolNotFound("tar")
        }
        progress(0.2, "Extracting TAR...")
        let process = Process()
        process.executableURL = toolURL

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
        guard let toolURL = Self.findTool(tool) else {
            throw ServiceError.toolNotFound(tool)
        }
        let process = Process()
        process.executableURL = toolURL
        process.arguments = args
        try await runProcess(process, progress: { _, _ in })
    }

    private func extractWithUnar(
        source: URL,
        dest: URL,
        password: String? = nil,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async throws {
        guard let unarURL = Self.findTool("unar") else {
            Self.logger.error("unar tool not found at expected paths")
            throw ServiceError.toolNotFound("unar")
        }
        progress(0.2, "Extracting...")
        Self.logger.debug("Extracting with unar: \(source.lastPathComponent, privacy: .public)")

        let process = Process()
        process.executableURL = unarURL

        var args = ["-o", dest.path, "-q"]
        if let password, !password.isEmpty {
            args.append(contentsOf: ["-p", password])
            Self.logger.debug("unar using password (length=\(password.count))")
        }
        args.append(source.path)
        process.arguments = args

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

        let cmd = (process.executableURL?.lastPathComponent ?? "?")
            + " " + (process.arguments?.joined(separator: " ") ?? "")
        Self.logger.debug("Running: \(cmd, privacy: .public)")

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                if proc.terminationStatus == 0 {
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    if !stdout.isEmpty {
                        Self.logger.debug("stdout: \(stdout, privacy: .public)")
                    }
                    continuation.resume()
                } else {
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    Self.logger.error("Process failed (exit=\(proc.terminationStatus)): \(cmd, privacy: .public)")
                    if !stderr.isEmpty {
                        Self.logger.error("stderr: \(stderr, privacy: .public)")
                    }
                    if !stdout.isEmpty {
                        Self.logger.error("stdout: \(stdout, privacy: .public)")
                    }
                    let errorMsg = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(
                        throwing: ServiceError.processError(
                            errorMsg.isEmpty ? "Exit code \(proc.terminationStatus)" : errorMsg
                        )
                    )
                }
            }

            do {
                try process.run()
            } catch {
                Self.logger.error("Failed to launch process: \(cmd, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                continuation.resume(throwing: ServiceError.processError(error.localizedDescription))
            }
        }
    }
}
