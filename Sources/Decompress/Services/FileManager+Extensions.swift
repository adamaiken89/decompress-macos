import Foundation

extension FileManager {
  func uniqueDirectoryURL(
    in parent: URL,
    preferredName: String
  ) -> URL {
    var url = parent.appendingPathComponent(preferredName)
    var counter = 1
    while fileExists(atPath: url.path) {
      url = parent.appendingPathComponent("\(preferredName) \(counter)")
      counter += 1
    }
    return url
  }

  func suggestedDestinationURL(for sourceURL: URL) -> URL {
    let path = sourceURL.path.lowercased()
    let allExtensions = ArchiveFormat.allCases
      .flatMap { $0.fileExtensions }
      .sorted { $0.count > $1.count }

    for ext in allExtensions {
      let suffix = ".\(ext)"
      if path.hasSuffix(suffix) {
        let name = String(path.dropLast(suffix.count))
        let parent = sourceURL.deletingLastPathComponent()
        return uniqueDirectoryURL(
          in: parent, preferredName: URL(fileURLWithPath: name).lastPathComponent)
      }
    }

    let sourceName =
      sourceURL
      .deletingPathExtension()
      .lastPathComponent
    let parent = sourceURL.deletingLastPathComponent()
    return uniqueDirectoryURL(in: parent, preferredName: sourceName)
  }

  func countFilesRecursively(at url: URL) -> Int {
    guard
      let enumerator = enumerator(
        at: url,
        includingPropertiesForKeys: nil
      )
    else { return 0 }
    var count = 0
    while enumerator.nextObject() != nil {
      count += 1
    }
    return count
  }
}
