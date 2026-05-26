import Foundation

enum ArchiveFormatDetector {
    static func detectFormat(from url: URL) -> ArchiveFormat? {
        detectFormatByExtension(from: url) ?? detectFormatByMagicBytes(from: url)
    }

    static func isZipEncrypted(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        let header = handle.readData(ofLength: 30)
        guard header.count >= 8,
              header[0..<4] == ArchiveFormat.zip.magicBytes[0]
        else { return false }
        return (header[6] & 0x01) != 0
    }

    private static func detectFormatByExtension(from url: URL) -> ArchiveFormat? {
        let path = url.path.lowercased()
        let sortedFormats = ArchiveFormat.allCases.sorted { lhs, rhs in
            let lhsLen = lhs.fileExtensions.map(\.count).max() ?? 0
            let rhsLen = rhs.fileExtensions.map(\.count).max() ?? 0
            return lhsLen > rhsLen
        }
        for format in sortedFormats {
            for ext in format.fileExtensions where path.hasSuffix(".\(ext)") {
                return format
            }
        }
        return nil
    }

    private static func detectFormatByMagicBytes(from url: URL) -> ArchiveFormat? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let headerData = handle.readData(ofLength: 16)
        guard headerData.count >= 4 else { return nil }

        for format in ArchiveFormat.allCases where !format.magicBytes.isEmpty {
            for magic in format.magicBytes where headerData.starts(with: magic) {
                return format
            }
        }
        return nil
    }
}
