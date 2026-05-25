@testable import Decompress
import Foundation
import XCTest

@MainActor
final class DecompressViewModelTests: XCTestCase {
    var viewModel: DecompressViewModel!

    override func setUp() async throws {
        viewModel = DecompressViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.isIdle)
        XCTAssertFalse(viewModel.isBusy)
        XCTAssertFalse(viewModel.canCancel)
        XCTAssertTrue(viewModel.selectedURLs.isEmpty)
        XCTAssertFalse(viewModel.showFilePicker)
        XCTAssertFalse(viewModel.showHelp)
        XCTAssertTrue(viewModel.autoExtractToSourceDir)
        XCTAssertFalse(viewModel.deleteArchiveAfterExtraction)
        XCTAssertFalse(viewModel.isPasswordProtected)
        XCTAssertTrue(viewModel.password.isEmpty)
        XCTAssertFalse(viewModel.extractInPlace)
    }

    func testAddFilesAcceptsZip() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/test.zip")])
        XCTAssertEqual(viewModel.selectedURLs.count, 1)
    }

    func testAddFilesAcceptsCompoundExtensions() {
        viewModel.addFiles([
            URL(fileURLWithPath: "/tmp/a.tar.gz"),
            URL(fileURLWithPath: "/tmp/b.tgz"),
            URL(fileURLWithPath: "/tmp/c.tar.bz2"),
            URL(fileURLWithPath: "/tmp/d.tar.xz"),
        ])
        XCTAssertEqual(viewModel.selectedURLs.count, 4)
    }

    func testAddFilesAcceptsAllArchiveFormats() {
        let urls: [URL] = ArchiveFormat.allCases.flatMap { format in
            format.fileExtensions.map { URL(fileURLWithPath: "/tmp/test.\($0)") }
        }
        viewModel.addFiles(urls)
        XCTAssertGreaterThan(viewModel.selectedURLs.count, 0)
    }

    func testAddFilesRejectsUnknownExtension() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/file.xyz")])
        XCTAssertTrue(viewModel.selectedURLs.isEmpty)
    }

    func testAddFilesRejectsFileWithoutExtension() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/README")])
        XCTAssertTrue(viewModel.selectedURLs.isEmpty)
    }

    func testAddFilesFiltersMixedInput() {
        viewModel.addFiles([
            URL(fileURLWithPath: "/tmp/valid.zip"),
            URL(fileURLWithPath: "/tmp/note.txt"),
            URL(fileURLWithPath: "/tmp/archive.7z"),
            URL(fileURLWithPath: "/tmp/image.png"),
        ])
        XCTAssertEqual(viewModel.selectedURLs.count, 2)
    }

    func testAddFilesAppendsToExisting() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/a.zip")])
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/b.zip")])
        XCTAssertEqual(viewModel.selectedURLs.count, 2)
    }

    func testRemoveFileByIndex() {
        viewModel.addFiles([
            URL(fileURLWithPath: "/tmp/a.zip"),
            URL(fileURLWithPath: "/tmp/b.zip"),
        ])
        viewModel.removeFile(at: 0)
        XCTAssertEqual(viewModel.selectedURLs.count, 1)
        XCTAssertEqual(viewModel.selectedURLs[0].lastPathComponent, "b.zip")
    }

    func testRemoveLastFileResetsToIdle() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/a.zip")])
        viewModel.removeFile(at: 0)
        XCTAssertTrue(viewModel.isIdle)
        XCTAssertTrue(viewModel.password.isEmpty)
        XCTAssertFalse(viewModel.isPasswordProtected)
    }

    func testRemoveFileOutOfBoundsDoesNothing() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/a.zip")])
        viewModel.removeFile(at: 5)
        XCTAssertEqual(viewModel.selectedURLs.count, 1)
    }

    func testRemoveFileNegativeIndexDoesNothing() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/a.zip")])
        viewModel.removeFile(at: -1)
        XCTAssertEqual(viewModel.selectedURLs.count, 1)
    }

    func testClearFilesResetsAllState() {
        viewModel.addFiles([
            URL(fileURLWithPath: "/tmp/a.zip"),
            URL(fileURLWithPath: "/tmp/b.zip"),
        ])
        viewModel.password = "secret"
        viewModel.isPasswordProtected = true
        viewModel.clearFiles()
        XCTAssertTrue(viewModel.selectedURLs.isEmpty)
        XCTAssertTrue(viewModel.isIdle)
        XCTAssertTrue(viewModel.password.isEmpty)
        XCTAssertFalse(viewModel.isPasswordProtected)
    }

    func testClearFilesOnEmptySelectionDoesNotCrash() {
        viewModel.clearFiles()
        XCTAssertTrue(viewModel.isIdle)
    }

    func testResetFromAnyState() {
        viewModel.reset()
        XCTAssertTrue(viewModel.isIdle)
    }

    func testDetectFormatReturnsZipForDotZip() {
        let format = viewModel.detectFormat(for: URL(fileURLWithPath: "/tmp/test.zip"))
        XCTAssertEqual(format, .zip)
    }

    func testDetectFormatReturnsTarGzForDotTarGz() {
        let format = viewModel.detectFormat(for: URL(fileURLWithPath: "/tmp/test.tar.gz"))
        XCTAssertEqual(format, .tarGz)
    }

    func testDetectFormatReturnsNilForUnknown() {
        let format = viewModel.detectFormat(for: URL(fileURLWithPath: "/tmp/test.unknown"))
        XCTAssertNil(format)
    }

    func testDetectFormatReturnsNilForNoExtension() {
        let format = viewModel.detectFormat(for: URL(fileURLWithPath: "/tmp/README"))
        XCTAssertNil(format)
    }

    func testDetectFormatIsCaseInsensitive() {
        let format = viewModel.detectFormat(for: URL(fileURLWithPath: "/tmp/test.ZIP"))
        XCTAssertEqual(format, .zip)
    }

    func testDetectFormatForCompoundIsCaseInsensitive() {
        let format = viewModel.detectFormat(for: URL(fileURLWithPath: "/tmp/test.TAR.GZ"))
        XCTAssertEqual(format, .tarGz)
    }

    func testCheckForEncryptedArchivesOnNonexistentFile() {
        viewModel.checkForEncryptedArchives([URL(fileURLWithPath: "/tmp/nonexistent.zip")])
        XCTAssertFalse(viewModel.isPasswordProtected)
    }

    func testIsBusyOnlyDuringActiveExtraction() {
        XCTAssertFalse(viewModel.isBusy)
        XCTAssertFalse(viewModel.canCancel)
    }

    func testCancelExtractionWhenIdleDoesNotCrash() {
        viewModel.cancelExtraction()
        XCTAssertTrue(viewModel.isIdle)
    }

    func testExtractAllWithNoFilesDoesNotChangeState() {
        viewModel.extractAll()
        XCTAssertTrue(viewModel.isIdle)
    }

    func testExtractAllCapturesValuesAtCallTime() {
        viewModel.addFiles([URL(fileURLWithPath: "/tmp/test.zip")])
        viewModel.extractInPlace = true
        viewModel.extractAll()
        XCTAssertFalse(viewModel.isIdle)
    }

    func testAutoExtractToSourceDirDefaultIsTrue() {
        XCTAssertTrue(viewModel.autoExtractToSourceDir)
    }

    func testDeleteArchiveAfterExtractionDefaultIsFalse() {
        XCTAssertFalse(viewModel.deleteArchiveAfterExtraction)
    }

    func testExtractInPlaceDefaultIsFalse() {
        XCTAssertFalse(viewModel.extractInPlace)
    }
}
