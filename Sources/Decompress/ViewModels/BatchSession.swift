import Foundation

struct BatchSession: Sendable, Equatable {
  private(set) var urls: [URL] = []
  private(set) var contents: [ArchiveContent] = []
  private(set) var formats: [URL: ArchiveFormat] = [:]
  private(set) var lastResult: BatchResult?
  private(set) var extractionStartTime: Date?

  var isEmpty: Bool { urls.isEmpty }

  var lastFailedSourceURL: URL? {
    lastResult?.failures.last?.sourceURL
  }

  mutating func add(_ newURLs: [URL]) {
    let archiveURLs = newURLs.filter { url in
      ArchiveFormatDetector.detectFormat(from: url) != nil
    }

    let filtered = archiveURLs.filter { url in
      guard let info = ArchiveFormatDetector.splitPartInfo(for: url), info.partNumber > 1 else {
        return true
      }
      let allCandidateURLs = urls + archiveURLs
      return !allCandidateURLs.contains { candidate in
        guard candidate != url,
          let candidateInfo = ArchiveFormatDetector.splitPartInfo(for: candidate)
        else {
          return false
        }
        return candidateInfo.groupKey == info.groupKey && candidateInfo.partNumber == 1
      }
    }

    urls.append(contentsOf: filtered)
  }

  @discardableResult
  mutating func remove(at index: Int) -> Bool {
    guard urls.indices.contains(index) else { return false }
    urls.remove(at: index)
    return urls.isEmpty
  }

  mutating func record(format: ArchiveFormat, for url: URL) {
    formats[url] = format
  }

  mutating func setContents(_ newContents: [ArchiveContent]) {
    contents = newContents
  }

  mutating func clearContents() {
    contents = []
  }

  mutating func recordResult(_ result: BatchResult) {
    lastResult = result
  }

  mutating func markStarted(at date: Date = Date()) {
    extractionStartTime = date
  }

  mutating func clearStartTime() {
    extractionStartTime = nil
  }

  mutating func reset() {
    self = BatchSession()
  }
}
