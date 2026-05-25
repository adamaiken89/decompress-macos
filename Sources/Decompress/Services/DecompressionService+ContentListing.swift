import Foundation

extension DecompressionService {
  func listContents(of url: URL, format: ArchiveFormat) async throws -> [ArchiveEntry] {
    switch format {
    case .zip:
      try await listZipContents(url)

    case .tar, .tarGz, .tarBz2, .tarXz:
      try await listTarContents(url, format: format)

    case .gzip, .bzip2, .xz:
      listSingleFileContents(url)

    case .sevenZip, .rar, .split:
      try await listUnarContents(url)
    }
  }

  private func listZipContents(_ url: URL) async throws -> [ArchiveEntry] {
    guard let toolURL = Self.findTool("unzip") else {
      throw ServiceError.toolNotFound("unzip")
    }
    let process = Process()
    process.executableURL = toolURL
    process.arguments = ["-l", url.path]

    let output = try await runProcess(forOutput: process)
    return parseZipListOutput(output)
  }

  private func parseZipListOutput(_ output: String) -> [ArchiveEntry] {
    var entries: [ArchiveEntry] = []
    let lines = output.components(separatedBy: .newlines)
    var parsingStarted = false
    var parsingEnded = false

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }

      if trimmed.range(of: "---") != nil {
        if !parsingStarted {
          parsingStarted = true
        } else {
          parsingEnded = true
        }
        continue
      }

      if parsingEnded || !parsingStarted { continue }

      let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
      guard parts.count >= 4, let size = Int64(parts[0]) else { continue }

      let name = String(parts[3])
      entries.append(ArchiveEntry(path: name, size: size, isDirectory: name.hasSuffix("/")))
    }

    return entries
  }

  private func listTarContents(_ url: URL, format: ArchiveFormat) async throws -> [ArchiveEntry] {
    guard let toolURL = Self.findTool("tar") else {
      throw ServiceError.toolNotFound("tar")
    }
    let process = Process()
    process.executableURL = toolURL

    switch format {
    case .tarGz:
      process.arguments = ["-tzf", url.path]

    case .tarBz2:
      process.arguments = ["-tjf", url.path]

    case .tarXz:
      process.arguments = ["-tJf", url.path]

    default:
      process.arguments = ["-tf", url.path]
    }

    let output = try await runProcess(forOutput: process)
    return parseTarListOutput(output)
  }

  private func parseTarListOutput(_ output: String) -> [ArchiveEntry] {
    output.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
      .map { path in
        ArchiveEntry(path: path, size: 0, isDirectory: path.hasSuffix("/"))
      }
  }

  private func listSingleFileContents(_ url: URL) -> [ArchiveEntry] {
    let name = url.deletingPathExtension().lastPathComponent
    return [ArchiveEntry(path: name, size: 0, isDirectory: false)]
  }

  private func listUnarContents(_ url: URL) async throws -> [ArchiveEntry] {
    guard let toolURL = Self.findTool("lsar") else {
      throw ServiceError.toolNotFound("lsar")
    }
    let process = Process()
    process.executableURL = toolURL
    process.arguments = [url.path]

    let output = try await runProcess(forOutput: process)
    return parseUnarListOutput(output)
  }

  private func parseUnarListOutput(_ output: String) -> [ArchiveEntry] {
    output.components(separatedBy: .newlines)
      .compactMap { line in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let path: String
        if let range = trimmed.range(of: " -- ") {
          path = String(trimmed[..<range.lowerBound])
        } else if let range = trimmed.range(of: " (") {
          path = String(trimmed[..<range.lowerBound])
        } else {
          path = trimmed
        }
        guard !path.isEmpty else { return nil }
        return ArchiveEntry(path: path, size: 0, isDirectory: path.hasSuffix("/"))
      }
  }
}
