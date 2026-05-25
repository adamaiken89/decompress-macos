@testable import Decompress
import Foundation
import XCTest

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

    func testUniqueDirectoryName() {
        let fileManager = FileManager.default
        let parent = URL(fileURLWithPath: "/tmp")
        let unique = fileManager.uniqueDirectoryURL(in: parent, preferredName: "test")
        XCTAssertEqual(unique.lastPathComponent, "test")
    }

    func testSuggestedDestinationForZip() {
        let fileManager = FileManager.default
        let source = URL(fileURLWithPath: "/Users/test/archive.zip")
        let dest = fileManager.suggestedDestinationURL(for: source)
        XCTAssertEqual(dest.lastPathComponent, "archive")
        XCTAssertEqual(dest.deletingLastPathComponent().path, "/Users/test")
    }

    func testSuggestedDestinationForTarGz() {
        let fileManager = FileManager.default
        let source = URL(fileURLWithPath: "/Users/test/archive.tar.gz")
        let dest = fileManager.suggestedDestinationURL(for: source)
        XCTAssertEqual(dest.lastPathComponent, "archive.tar")
    }
}
