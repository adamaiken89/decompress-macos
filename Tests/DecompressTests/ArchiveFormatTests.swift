@testable import Decompress
import Foundation
import XCTest

final class ArchiveFormatTests: XCTestCase {
    func testAllFormatsHaveDisplayName() {
        for format in ArchiveFormat.allCases {
            XCTAssertFalse(format.displayName.isEmpty)
        }
    }

    func testAllFormatsHaveExtensions() {
        for format in ArchiveFormat.allCases {
            XCTAssertFalse(format.fileExtensions.isEmpty)
        }
    }

    func testZipExtensions() {
        XCTAssertEqual(ArchiveFormat.zip.fileExtensions, ["zip"])
    }

    func testTarGzExtensions() {
        XCTAssertEqual(ArchiveFormat.tarGz.fileExtensions, ["tar.gz", "tgz"])
    }

    func testNoTwoFormatsShareAllExtensions() {
        let allCases = ArchiveFormat.allCases
        for firstIndex in 0..<allCases.count {
            for secondIndex in (firstIndex + 1)..<allCases.count {
                let first = allCases[firstIndex]
                let second = allCases[secondIndex]
                let common = Set(first.fileExtensions).intersection(second.fileExtensions)
                XCTAssertNotEqual(common, Set(first.fileExtensions), "\(first) and \(second) share all extensions")
            }
        }
    }

    func testMagicBytesNotEmpty() {
        let formatsWithoutMagic: Set<ArchiveFormat> = [.tar]
        for format in ArchiveFormat.allCases where !formatsWithoutMagic.contains(format) {
            XCTAssertFalse(format.magicBytes.isEmpty, "\(format) should have magic bytes")
        }
    }

    func testZipMagicBytes() {
        let zipMagic = Data([0x50, 0x4B, 0x03, 0x04])
        XCTAssertTrue(ArchiveFormat.zip.magicBytes.contains(zipMagic))
    }

    func testGzipMagicBytes() {
        let gzipMagic = Data([0x1F, 0x8B])
        XCTAssertTrue(ArchiveFormat.gzip.magicBytes.contains(gzipMagic))
        XCTAssertTrue(ArchiveFormat.tarGz.magicBytes.contains(gzipMagic))
    }
}
