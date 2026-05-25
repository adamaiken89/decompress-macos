import Foundation

struct ArchiveEntry: Sendable, Identifiable, Equatable, Hashable {
  let path: String
  let size: Int64
  let isDirectory: Bool

  var id: String { path }

  var fileName: String {
    (path as NSString).lastPathComponent
  }

  var parentPath: String {
    if isDirectory { return path }
    return (path as NSString).deletingLastPathComponent
  }
}

struct ArchiveContent: Sendable, Identifiable, Equatable {
  let sourceURL: URL
  let format: ArchiveFormat
  let entries: [ArchiveEntry]
  let listError: String?

  var id: URL { sourceURL }

  var archiveName: String { sourceURL.lastPathComponent }

  var totalSize: Int64 {
    entries.reduce(0) { $0 + $1.size }
  }

  var totalFiles: Int { entries.count }

  init(sourceURL: URL, format: ArchiveFormat, entries: [ArchiveEntry], listError: String? = nil) {
    self.sourceURL = sourceURL
    self.format = format
    self.entries = entries
    self.listError = listError
  }
}
