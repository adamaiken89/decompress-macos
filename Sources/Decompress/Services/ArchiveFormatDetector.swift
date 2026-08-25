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

  static func isEncrypted(url: URL, format: ArchiveFormat) -> Bool? {
    switch format {
    case .zip:
      return isZipEncrypted(url)

    case .sevenZip:
      return isSevenZipEncrypted(url)

    case .rar, .split, .tar, .tarGz, .tarBz2, .tarXz, .gzip, .bzip2, .xz:
      return nil
    }
  }

  static func splitPartInfo(for url: URL) -> (groupKey: String, partNumber: Int)? {
    let name = url.lastPathComponent

    if let match = try? /^(.+)\.part(\d+)\./.firstMatch(in: name) {
      return (String(match.1), Int(match.2) ?? 0)
    }

    if let match = try? /^(.+)\.(7z|zip)\.(\d{3})$/.firstMatch(in: name) {
      return (String(match.1), Int(match.3) ?? 0)
    }

    if let match = try? /^(.+)\.r(\d{2})$/.firstMatch(in: name) {
      return (String(match.1), Int(match.2) ?? 0)
    }

    if let match = try? /^(.+)\.(\d{3})$/.firstMatch(in: name) {
      return (String(match.1), Int(match.2) ?? 0)
    }

    return nil
  }

  private static func isSevenZipEncrypted(_ url: URL) -> Bool? {
    guard
      let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attrs[.size] as? Int64, size >= 32
    else { return nil }

    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    let header = handle.readData(ofLength: 32)
    guard header.count >= 32,
      header.starts(with: ArchiveFormat.sevenZip.magicBytes[0])
    else { return nil }

    let nextHeaderOffset = header.subdata(in: 12..<20)
    let nextHeaderSize = header.subdata(in: 20..<28)
    let offset = nextHeaderOffset.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
    let size64 = nextHeaderSize.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
    guard size64 > 0, offset + size64 <= UInt64(size) - 32 else { return false }

    try? handle.seek(toOffset: 32 + offset)
    guard let headerData = try? handle.read(upToCount: Int(size64)), headerData.count >= 1 else {
      return nil
    }

    let kEncodedHeader: UInt8 = 0x17
    if headerData[0] == kEncodedHeader { return true }
    let kCryptHashDigest: UInt8 = 0x0A
    return headerData.contains(kCryptHashDigest)
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
    for candidate in splitAwareNameCandidates(url.lastPathComponent.lowercased()) {
      for format in sortedFormats where format != .split {
        for ext in format.fileExtensions where candidate.hasSuffix(".\(ext)") {
          return format
        }
      }
    }
    return nil
  }

  private static func splitAwareNameCandidates(_ name: String) -> [String] {
    var candidates: [String] = []

    if let range = name.range(of: #"\.\d{3}$"#, options: .regularExpression) {
      candidates.append(String(name[..<range.lowerBound]))
    }

    if let range = name.range(of: #"\.r\d{2}$"#, options: .regularExpression) {
      candidates.append(String(name[..<range.lowerBound]) + ".rar")
    }

    if let range = name.range(of: #"\.part\d+"#, options: .regularExpression) {
      let base = String(name[..<range.lowerBound])
      let remainder = String(name[range.upperBound...])
      if !remainder.isEmpty && remainder.hasPrefix(".") {
        candidates.append(base + remainder)
      }
      candidates.append(base)
    }

    return candidates
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
