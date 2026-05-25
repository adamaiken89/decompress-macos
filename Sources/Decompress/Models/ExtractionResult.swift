import Foundation

struct ExtractionResult: Sendable {
    let sourceURL: URL
    let destinationURL: URL
    let format: ArchiveFormat
    let fileCount: Int
    let duration: TimeInterval
    let bytesExtracted: Int64

    var formattedDuration: String {
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

enum ExtractionState: Sendable {
    case idle
    case preparing
    case extracting(progress: Double, currentFile: String)
    case completed(ExtractionResult)
    case failed(String)
}
