import Foundation

enum ProcessOutputParser {
  static func cleanLine(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? nil : trimmed
  }

  static func entryName(from line: String) -> String? {
    if let name = unzipEntryName(from: line) { return name }
    if let name = unarEntryName(from: line) { return name }
    if let name = tarVerboseName(from: line) { return name }
    return nil
  }

  private static func unzipEntryName(from line: String) -> String? {
    for keyword in ["inflating:", "extracting:", "creating:", "replacing:", "file#"] {
      if let range = line.range(of: keyword) {
        let name = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        if !name.isEmpty, !isUnzipNoise(name) {
          return name
        }
      }
    }
    return nil
  }

  private static func isUnzipNoise(_ name: String) -> Bool {
    name.hasPrefix("Archive:")
      || name.hasPrefix("Length")
      || name.hasPrefix("--")
      || name.contains("files were successfully")
      || name.lowercased().contains("password")
  }

  private static func unarEntryName(from line: String) -> String? {
    guard !isUnarNoise(line) else { return nil }
    var candidate = line
    if let range = candidate.range(of: " -- ") {
      candidate = String(candidate[..<range.lowerBound])
    } else if let range = candidate.range(of: ": OK") {
      candidate = String(candidate[..<range.lowerBound])
    } else if let range = candidate.range(of: " (") {
      candidate = String(candidate[..<range.lowerBound])
    }
    candidate = candidate.trimmingCharacters(in: .whitespaces)
    return candidate.isEmpty ? nil : candidate
  }

  private static func isUnarNoise(_ line: String) -> Bool {
    line.lowercased().contains("extraction")
      || line.lowercased().contains("password")
      || line.hasPrefix("lsar")
      || line.hasPrefix("unar")
  }

  private static func tarVerboseName(from line: String) -> String? {
    guard !line.contains("->"), !isTarNoise(line), !line.hasSuffix("/") else { return nil }
    let cleaned =
      line
      .trimmingCharacters(in: CharacterSet(charactersIn: "x "))
    guard !cleaned.isEmpty, !isTarNoise(cleaned) else { return nil }
    return cleaned
  }

  private static func isTarNoise(_ line: String) -> Bool {
    line.isEmpty
      || line.hasPrefix("tar:")
      || line.lowercased().contains("total")
      || line.lowercased().contains("block")
  }
}
