import Foundation

enum ArchiveFormat: String, CaseIterable, Codable, Sendable {
    case zip
    case tar
    case gzip
    case bzip2
    case xz
    case tarGz
    case tarBz2
    case tarXz
    case sevenZip
    case rar

    var displayName: String {
        switch self {
        case .zip:
            "ZIP"

        case .tar:
            "TAR"

        case .gzip:
            "GZIP"

        case .bzip2:
            "BZIP2"

        case .xz:
            "XZ"

        case .tarGz:
            "TAR.GZ"

        case .tarBz2:
            "TAR.BZ2"

        case .tarXz:
            "TAR.XZ"

        case .sevenZip:
            "7Z"

        case .rar:
            "RAR"
        }
    }

    var fileExtensions: [String] {
        switch self {
        case .zip:
            ["zip"]

        case .tar:
            ["tar"]

        case .gzip:
            ["gz"]

        case .bzip2:
            ["bz2"]

        case .xz:
            ["xz"]

        case .tarGz:
            ["tar.gz", "tgz"]

        case .tarBz2:
            ["tar.bz2", "tbz2", "tbz"]

        case .tarXz:
            ["tar.xz", "txz"]

        case .sevenZip:
            ["7z"]

        case .rar:
            ["rar", "cbr"]
        }
    }

    var magicBytes: [Data] {
        switch self {
        case .zip:
            [Data([0x50, 0x4B, 0x03, 0x04]), Data([0x50, 0x4B, 0x05, 0x06]), Data([0x50, 0x4B, 0x07, 0x08])]

        case .tar:
            []

        case .gzip:
            [Data([0x1F, 0x8B])]

        case .bzip2:
            [Data([0x42, 0x5A])]

        case .xz:
            [Data([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00])]

        case .tarGz:
            [Data([0x1F, 0x8B])]

        case .tarBz2:
            [Data([0x42, 0x5A])]

        case .tarXz:
            [Data([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00])]

        case .sevenZip:
            [Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])]

        case .rar:
            [Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])]
        }
    }
}
