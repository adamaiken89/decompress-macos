import Foundation

enum ServiceError: Error, LocalizedError, Sendable {
  case unsupportedFormat(String)
  case fileNotFound(URL)
  case extractionFailed(String)
  case destinationCreationFailed(URL)
  case processError(String)
  case passwordRequired
  case toolNotFound(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedFormat(let ext):
      String(format: loc("Unsupported archive format: %@"), ext)

    case .fileNotFound(let url):
      String(format: loc("File not found: %@"), url.lastPathComponent)

    case .extractionFailed(let reason):
      String(format: loc("Extraction failed: %@"), reason)

    case .destinationCreationFailed(let url):
      String(format: loc("Could not create destination: %@"), url.path)

    case .processError(let msg):
      String(format: loc("Process error: %@"), msg)

    case .passwordRequired:
      loc("Password is required for this archive")

    case .toolNotFound(let name):
      String(format: loc("Required tool not found: %1$@. Install with: brew install %1$@"), name)
    }
  }
}
