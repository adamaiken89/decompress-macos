import Foundation
import XCTest

@testable import Decompress

final class DecompressionServiceTests: XCTestCase {
  let service = DecompressionService.shared

  func testDetectZipByExtension() {
    let url = URL(fileURLWithPath: "/tmp/test.zip")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .zip)
  }

  func testDetectTarGzByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.tar.gz")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .tarGz)
  }

  func testDetectTgzByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.tgz")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .tarGz)
  }

  func testDetectTarBz2ByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.tar.bz2")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .tarBz2)
  }

  func testDetectTbzByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.tbz")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .tarBz2)
  }

  func testDetectTarXzByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.tar.xz")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .tarXz)
  }

  func testDetectSevenZipByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.7z")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .sevenZip)
  }

  func testDetectRarByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.rar")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .rar)
  }

  func testDetectSplitByExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.001")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .split)
  }

  func testDetectFormatFromNonexistentFile() {
    let url = URL(fileURLWithPath: "/tmp/nonexistent.xyz")
    let format = service.detectFormat(from: url)
    XCTAssertNil(format)
  }

  func testDetectFormatFromUnknownExtension() {
    let url = URL(fileURLWithPath: "/tmp/file.unknown")
    let format = service.detectFormat(from: url)
    XCTAssertNil(format)
  }

  func testDetectFormatCaseInsensitiveUppercase() {
    let url = URL(fileURLWithPath: "/tmp/ARCHIVE.ZIP")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .zip)
  }

  func testDetectFormatCaseInsensitiveMixedCase() {
    let url = URL(fileURLWithPath: "/tmp/Archive.Tar.Gz")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .tarGz)
  }

  func testDetectFormatPrefersLongestExtension() {
    let url = URL(fileURLWithPath: "/tmp/archive.tar.gz")
    let format = service.detectFormat(from: url)
    XCTAssertEqual(format, .tarGz)
  }

  func testDetectFormatFileWithoutExtension() {
    let url = URL(fileURLWithPath: "/tmp/README")
    let format = service.detectFormat(from: url)
    XCTAssertNil(format)
  }

  func testDetectFormatDotfile() {
    let url = URL(fileURLWithPath: "/tmp/.hidden")
    let format = service.detectFormat(from: url)
    XCTAssertNil(format)
  }

  func testSuggestedDestinationForZip() {
    let source = URL(fileURLWithPath: "/Users/test/archive.zip")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
    XCTAssertEqual(dest.deletingLastPathComponent().path, "/Users/test")
  }

  func testSuggestedDestinationForTarGz() {
    let source = URL(fileURLWithPath: "/Users/test/archive.tar.gz")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForTgz() {
    let source = URL(fileURLWithPath: "/Users/test/archive.tgz")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForTarBz2() {
    let source = URL(fileURLWithPath: "/Users/test/archive.tar.bz2")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForTbz() {
    let source = URL(fileURLWithPath: "/Users/test/archive.tbz")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForTarXz() {
    let source = URL(fileURLWithPath: "/Users/test/archive.tar.xz")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForSevenZip() {
    let source = URL(fileURLWithPath: "/Users/test/archive.7z")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForRar() {
    let source = URL(fileURLWithPath: "/Users/test/archive.rar")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForSplit() {
    let source = URL(fileURLWithPath: "/Users/test/archive.001")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForGzip() {
    let source = URL(fileURLWithPath: "/Users/test/archive.gz")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForBzip2() {
    let source = URL(fileURLWithPath: "/Users/test/archive.bz2")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForXz() {
    let source = URL(fileURLWithPath: "/Users/test/archive.xz")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "archive")
  }

  func testSuggestedDestinationForCbr() {
    let source = URL(fileURLWithPath: "/Users/test/comic.cbr")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "comic")
  }

  func testSuggestedDestinationForFileWithMultipleDots() {
    let source = URL(fileURLWithPath: "/Users/test/my.file.name.zip")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.lastPathComponent, "my.file.name")
  }

  func testSuggestedDestinationPreservesParentDirectory() {
    let source = URL(fileURLWithPath: "/Users/me/Documents/archive.zip")
    let dest = FileManager.default.suggestedDestinationURL(for: source)
    XCTAssertEqual(dest.deletingLastPathComponent().path, "/Users/me/Documents")
  }

  func testUniqueDirectoryName() {
    let parent = URL(fileURLWithPath: "/tmp")
    let unique = FileManager.default.uniqueDirectoryURL(in: parent, preferredName: "test")
    XCTAssertEqual(unique.lastPathComponent, "test")
  }
}
