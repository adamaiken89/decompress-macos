import Foundation
import OSLog

actor DecompressionService {
  static let logger = Logger(subsystem: "com.decompress", category: "service")

  static let shared = DecompressionService()
  private init() {}

  nonisolated func detectFormat(from url: URL) -> ArchiveFormat? {
    let result = ArchiveFormatDetector.detectFormat(from: url)
    Self.logger.debug(
      "Detect format: \(url.lastPathComponent, privacy: .public) -> \(result?.rawValue ?? "nil", privacy: .public)"
    )
    return result
  }

  nonisolated func isZipEncrypted(_ url: URL) -> Bool {
    let result = ArchiveFormatDetector.isZipEncrypted(url)
    Self.logger.debug(
      "ZIP encrypted check: \(url.lastPathComponent, privacy: .public) -> \(result)")
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

  func cancelRunningProcesses() {
    _ = RunningProcessTracker.shared.terminateAll()
  }

  func extract(
    sourceURL: URL,
    destinationURL: URL,
    format: ArchiveFormat,
    password: String? = nil,
    selectedEntries: [String]? = nil,
    allowNonEmptyDestination: Bool = false,
    progressHandler: @Sendable @escaping (Double, String) -> Void
  ) async throws -> ExtractionResult {
    Self.logger.debug(
      "Extract start: \(sourceURL.lastPathComponent, privacy: .public) format=\(format.rawValue, privacy: .public) dest=\(destinationURL.path, privacy: .public) hasPassword=\(password != nil, privacy: .public) hasSelection=\(selectedEntries != nil, privacy: .public)"
    )

    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      Self.logger.error("File not found: \(sourceURL.path, privacy: .public)")
      throw ServiceError.fileNotFound(sourceURL)
    }

    if !allowNonEmptyDestination,
      FileManager.default.fileExists(atPath: destinationURL.path),
      let existing = try? FileManager.default.contentsOfDirectory(atPath: destinationURL.path),
      !existing.isEmpty
    {
      throw ServiceError.destinationNotEmpty(destinationURL)
    }

    try FileManager.default.createDirectory(
      at: destinationURL, withIntermediateDirectories: true, attributes: nil)
    progressHandler(0.1, loc("Preparing..."))

    let startTime = Date()
    let sourceSize = Self.readFileSize(sourceURL)

    switch format {
    case .zip:
      try await extractZip(
        source: sourceURL,
        dest: destinationURL,
        password: password,
        selectedEntries: selectedEntries,
        progress: progressHandler
      )

    case .tar, .tarGz, .tarBz2, .tarXz:
      try await extractTar(
        source: sourceURL,
        dest: destinationURL,
        format: format,
        selectedEntries: selectedEntries,
        progress: progressHandler
      )

    case .gzip:
      try await extractSingleFile(
        source: sourceURL, dest: destinationURL, tool: "gunzip", args: ["-f", sourceURL.path])

    case .bzip2:
      try await extractSingleFile(
        source: sourceURL, dest: destinationURL, tool: "bunzip2", args: ["-f", sourceURL.path])

    case .xz:
      try await extractSingleFile(
        source: sourceURL, dest: destinationURL, tool: "unxz", args: ["-f", sourceURL.path])

    case .sevenZip, .rar, .split:
      try await extractWithUnar(
        source: sourceURL,
        dest: destinationURL,
        password: password,
        selectedEntries: selectedEntries,
        progress: progressHandler
      )
    }

    return await completeExtraction(
      sourceURL: sourceURL,
      destinationURL: destinationURL,
      format: format,
      startTime: startTime,
      sourceSize: sourceSize
    )
  }
}

// MARK: - ZIP Extraction

extension DecompressionService {
  private func extractZip(
    source: URL,
    dest: URL,
    password: String?,
    selectedEntries: [String]?,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    if let entries = selectedEntries, !entries.isEmpty {
      try await extractZipSelected(
        source: source, dest: dest, entries: entries, password: password, progress: progress)
    } else if let password, !password.isEmpty {
      try await extractZipWithPassword(
        source: source, dest: dest, password: password, progress: progress)
    } else {
      try await extractZipDitto(source: source, dest: dest, progress: progress)
    }
  }

  private func extractZipDitto(
    source: URL,
    dest: URL,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    guard let toolURL = Self.findTool("ditto") else {
      throw ServiceError.toolNotFound("ditto")
    }
    progress(0.2, loc("Extracting ZIP..."))
    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["-x", "-k", source.path, dest.path]
    try await runProcess(process, sourceURL: source, progress: progress)
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
    progress(0.2, loc("Extracting encrypted ZIP..."))
    try await runProcessWithPassword(
      toolURL: toolURL,
      arguments: ["-o", source.path, "-d", dest.path],
      password: password,
      sourceURL: source,
      totalUnits: nil,
      progress: progress
    )
  }

  private func extractZipSelected(
    source: URL,
    dest: URL,
    entries: [String],
    password: String?,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    guard let toolURL = Self.findTool("unzip") else {
      throw ServiceError.toolNotFound("unzip")
    }
    progress(0.2, loc("Extracting selected files..."))

    if let password, !password.isEmpty {
      try await runProcessWithPassword(
        toolURL: toolURL,
        arguments: ["-o", source.path, "--"] + entries + ["-d", dest.path],
        password: password,
        sourceURL: source,
        totalUnits: entries.count,
        progress: progress
      )
    } else {
      let process = Process()
      process.executableURL = toolURL
      process.arguments = ["-o", source.path, "--"] + entries + ["-d", dest.path]
      try await runProcess(
        process, sourceURL: source, totalUnits: entries.count, progress: progress)
    }
  }
}

// MARK: - Extraction helpers

extension DecompressionService {
  static func readFileSize(_ url: URL) -> Int64 {
    (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
  }

  private func completeExtraction(
    sourceURL: URL,
    destinationURL: URL,
    format: ArchiveFormat,
    startTime: Date,
    sourceSize: Int64
  ) async -> ExtractionResult {
    let duration = Date().timeIntervalSince(startTime)
    let fileCount = FileManager.default.countFilesRecursively(at: destinationURL)

    Self.logger.debug(
      "Extract success: \(sourceURL.lastPathComponent, privacy: .public) files=\(fileCount) duration=\(duration, format: .fixed(precision: 2))s"
    )

    return ExtractionResult(
      sourceURL: sourceURL,
      destinationURL: destinationURL,
      format: format,
      fileCount: fileCount,
      duration: duration,
      bytesExtracted: sourceSize
    )
  }
}

// MARK: - TAR Extraction

extension DecompressionService {
  private func extractTar(
    source: URL,
    dest: URL,
    format: ArchiveFormat,
    selectedEntries: [String]?,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    if let entries = selectedEntries, !entries.isEmpty {
      try await extractTarSelected(
        source: source, dest: dest, format: format, entries: entries, progress: progress)
    } else {
      try await extractTarFull(source: source, dest: dest, format: format, progress: progress)
    }
  }

  private func extractTarFull(
    source: URL,
    dest: URL,
    format: ArchiveFormat,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    guard let toolURL = Self.findTool("tar") else {
      throw ServiceError.toolNotFound("tar")
    }
    progress(0.2, loc("Extracting TAR..."))
    let process = Process()
    process.executableURL = toolURL
    process.arguments = tarExtractArgs(for: format, source: source, dest: dest)
    try await runProcess(process, sourceURL: source, progress: progress)
  }

  private func extractTarSelected(
    source: URL,
    dest: URL,
    format: ArchiveFormat,
    entries: [String],
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    guard let toolURL = Self.findTool("tar") else {
      throw ServiceError.toolNotFound("tar")
    }
    progress(0.2, loc("Extracting selected files..."))
    let process = Process()
    process.executableURL = toolURL
    process.arguments = tarExtractArgs(for: format, source: source, dest: dest) + ["--"] + entries
    try await runProcess(
      process, sourceURL: source, totalUnits: entries.count, progress: progress)
  }

  private func tarExtractArgs(for format: ArchiveFormat, source: URL, dest: URL) -> [String] {
    switch format {
    case .tarGz:
      ["-xvzf", source.path, "-C", dest.path]

    case .tarBz2:
      ["-xvjf", source.path, "-C", dest.path]

    case .tarXz:
      ["-xvJf", source.path, "-C", dest.path]

    default:
      ["-xvf", source.path, "-C", dest.path]
    }
  }
}

// MARK: - Single-file Extraction

extension DecompressionService {
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
    try await runProcess(process, sourceURL: source, progress: { _, _ in })
  }
}

// MARK: - Unar Extraction

extension DecompressionService {
  private func extractWithUnar(
    source: URL,
    dest: URL,
    password: String?,
    selectedEntries: [String]?,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    if let entries = selectedEntries, !entries.isEmpty {
      try await extractWithUnarSelected(
        source: source, dest: dest, entries: entries, password: password, progress: progress)
    } else if let password, !password.isEmpty {
      try await extractWithUnarFull(
        source: source, dest: dest, password: password, progress: progress)
    } else {
      try await extractWithUnarFull(source: source, dest: dest, progress: progress)
    }
  }

  private func extractWithUnarFull(
    source: URL,
    dest: URL,
    password: String? = nil,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    guard let unarURL = Self.findTool("unar") else {
      Self.logger.error("unar tool not found at expected paths")
      throw ServiceError.toolNotFound("unar")
    }
    progress(0.2, loc("Extracting..."))
    Self.logger.debug("Extracting with unar: \(source.lastPathComponent, privacy: .public)")

    var args = ["-o", dest.path]
    if let password, !password.isEmpty {
      Self.logger.debug("unar using secure password prompt (length=\(password.count))")
    }
    args.append(source.path)

    try await runProcessWithPassword(
      toolURL: unarURL,
      arguments: args,
      password: password,
      sourceURL: source,
      totalUnits: nil,
      progress: progress
    )
  }

  private func extractWithUnarSelected(
    source: URL,
    dest: URL,
    entries: [String],
    password: String?,
    progress: @Sendable @escaping (Double, String) -> Void
  ) async throws {
    guard let unarURL = Self.findTool("unar") else {
      Self.logger.error("unar tool not found at expected paths")
      throw ServiceError.toolNotFound("unar")
    }
    progress(0.2, loc("Extracting selected files..."))
    Self.logger.debug(
      "Extracting selected with unar: \(source.lastPathComponent, privacy: .public)")

    var args = ["-o", dest.path]
    for entry in entries {
      args += ["-i", entry]
    }
    args += ["--", source.path]

    try await runProcessWithPassword(
      toolURL: unarURL,
      arguments: args,
      password: password,
      sourceURL: source,
      totalUnits: entries.count,
      progress: progress
    )
  }
}
