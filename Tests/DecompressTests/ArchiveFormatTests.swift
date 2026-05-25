import Foundation
import XCTest

@testable import Decompress

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
        XCTAssertNotEqual(
          common, Set(first.fileExtensions), "\(first) and \(second) share all extensions")
      }
    }
  }

  func testMagicBytesNotEmpty() {
    let formatsWithoutMagic: Set<ArchiveFormat> = [.tar, .split]
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

  func testSevenZipMagicBytes() {
    let sevenZMagic = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
    XCTAssertTrue(ArchiveFormat.sevenZip.magicBytes.contains(sevenZMagic))
  }

  func testRarMagicBytes() {
    let rarMagic = Data([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])
    XCTAssertTrue(ArchiveFormat.rar.magicBytes.contains(rarMagic))
  }

  func testBzip2MagicBytes() {
    let bz2Magic = Data([0x42, 0x5A])
    XCTAssertTrue(ArchiveFormat.bzip2.magicBytes.contains(bz2Magic))
    XCTAssertTrue(ArchiveFormat.tarBz2.magicBytes.contains(bz2Magic))
  }

  func testXzMagicBytes() {
    let xzMagic = Data([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00])
    XCTAssertTrue(ArchiveFormat.xz.magicBytes.contains(xzMagic))
    XCTAssertTrue(ArchiveFormat.tarXz.magicBytes.contains(xzMagic))
  }

  func testTarAndSplitHaveNoMagicBytes() {
    XCTAssertTrue(ArchiveFormat.tar.magicBytes.isEmpty)
    XCTAssertTrue(ArchiveFormat.split.magicBytes.isEmpty)
  }

  func testAllDisplayNamesAreUppercase() {
    for format in ArchiveFormat.allCases {
      let name = format.displayName
      XCTAssertEqual(name, name.uppercased(), "\(format).displayName should be uppercase")
    }
  }

  func testSevenZipExtensions() {
    XCTAssertEqual(ArchiveFormat.sevenZip.fileExtensions, ["7z"])
  }

  func testRarExtensions() {
    XCTAssertEqual(ArchiveFormat.rar.fileExtensions, ["rar", "cbr"])
  }

  func testSplitExtensions() {
    XCTAssertEqual(ArchiveFormat.split.fileExtensions, ["001"])
  }

  func testNoDuplicateExtensionAcrossFormats() {
    var seen: [String: ArchiveFormat] = [:]
    for format in ArchiveFormat.allCases {
      for ext in format.fileExtensions {
        if let existing = seen[ext] {
          XCTFail("Extension '\(ext)' is claimed by both \(existing) and \(format)")
        }
        seen[ext] = format
      }
    }
  }

  func testCompoundExtensionsContainDot() {
    for format in ArchiveFormat.allCases {
      for ext in format.fileExtensions where ext.contains(".") {
        let parts = ext.split(separator: ".")
        XCTAssertGreaterThan(
          parts.count, 1, "Compound extension should have multiple parts: \(ext)")
      }
    }
  }

  func testAllCaseIterableCoverage() {
    let expectedCount = 11
    XCTAssertEqual(ArchiveFormat.allCases.count, expectedCount, "Add new cases to this test")
  }
}
