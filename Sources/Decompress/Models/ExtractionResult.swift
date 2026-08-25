import Foundation

struct ExtractionResult: Sendable, Equatable {
  let sourceURL: URL
  let destinationURL: URL
  let format: ArchiveFormat
  let fileCount: Int
  let duration: TimeInterval
  let bytesExtracted: Int64

  var formattedDuration: String? {
    guard duration >= 1.0 else { return nil }
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: duration) ?? "\(String(format: "%.1f", duration))s"
  }

  var formattedSize: String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytesExtracted)
  }
}

struct BatchResult: Sendable, Equatable {
  let successes: [ExtractionResult]
  let failures: [Self.Failure]

  struct Failure: Sendable, Equatable {
    let sourceURL: URL
    let error: String
    var isPasswordError: Bool
  }

  var totalCount: Int { successes.count + failures.count }
  var allSucceeded: Bool { failures.isEmpty }
  var hasPasswordFailuresOnly: Bool {
    !failures.isEmpty && successes.isEmpty && failures.allSatisfy(\.isPasswordError)
  }
}

enum ExtractionPhase: Sendable, Equatable {
  case idle
  case extracting(
    progress: Double?, currentFile: String?, archiveIndex: Int, totalArchives: Int)
  case browsing
  case completed(BatchResult)
  case failed(String)

  static func preparing(totalArchives: Int) -> ExtractionPhase {
    .extracting(progress: nil, currentFile: nil, archiveIndex: 0, totalArchives: totalArchives)
  }
}

extension ExtractionPhase {
  var isBusy: Bool {
    if case .extracting = self { return true }
    return false
  }

  var canCancel: Bool { isBusy }
}
