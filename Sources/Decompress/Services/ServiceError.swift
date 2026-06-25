import Foundation

enum ServiceError: Error, LocalizedError, Sendable {
  case unsupportedFormat(String)
  case fileNotFound(URL)
  case extractionFailed(String)
  case destinationCreationFailed(URL)
  case processError(String)
  case processExit(String, Int32)
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

    case .processExit(let tool, let code):
      Self.exitCodeMessage(tool: tool, code: code)

    case .passwordRequired:
      loc("Password is required for this archive")

    case .toolNotFound(let name):
      String(format: loc("Required tool not found: %1$@. Install with: brew install %1$@"), name)
    }
  }

  private static func exitCodeMessage(tool: String, code: Int32) -> String {
    let toolName = tool.hasSuffix("/") ? URL(fileURLWithPath: tool).lastPathComponent : tool
    let messages: [String: [Int32: String]] = [
      "unzip": [
        1: loc("Warning occurred during extraction"),
        2: loc("Serious error — zip file may be corrupted"),
        81: loc("Out of memory — archive too large"),
        82: loc("Unexpected end of archive — file may be truncated"),
      ],
      "tar": [
        1: loc("Warning occurred during extraction"),
        2: loc("Fatal error — archive may be corrupted"),
      ],
      "unar": [
        1: loc("Minor issues during extraction"),
        2: loc("Could not find or read archive"),
        3: loc("Password incorrect or archive corrupted"),
      ],
      "ditto": [
        1: loc("Extraction failed — destination may already exist")
      ],
    ]
    if let toolCodes = messages[toolName], let msg = toolCodes[code] {
      return msg
    }
    return String(format: loc("Extraction failed (exit code %d)"), code)
  }
}
