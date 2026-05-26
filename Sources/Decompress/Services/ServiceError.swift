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
            "Unsupported archive format: \(ext)"

        case .fileNotFound(let url):
            "File not found: \(url.lastPathComponent)"

        case .extractionFailed(let reason):
            "Extraction failed: \(reason)"

        case .destinationCreationFailed(let url):
            "Could not create destination: \(url.path)"

        case .processError(let msg):
            "Process error: \(msg)"

        case .passwordRequired:
            "Password is required for this archive"

        case .toolNotFound(let name):
            "Required tool not found: \(name). Install with: brew install \(name)"
        }
    }
}
