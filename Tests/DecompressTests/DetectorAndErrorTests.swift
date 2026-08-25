import Foundation
import XCTest

@testable import Decompress

final class DetectorAndErrorTests: XCTestCase {
  private func makeTempFile(name: String, contents: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "decompress-tests-\(UUID().uuidString)-\(name)")
    try contents.write(to: url)
    return url
  }

  private func cleanup(_ urls: [URL]) {
    for url in urls {
      try? FileManager.default.removeItem(at: url)
    }
  }

  // MARK: - Split-aware extension detection

  func testDetectFormatForTarWithPartSuffix() {
    XCTAssertEqual(
      ArchiveFormatDetector.detectFormat(from: URL(fileURLWithPath: "/tmp/x.tar.part2")), .tar)
    XCTAssertEqual(
      ArchiveFormatDetector.detectFormat(from: URL(fileURLWithPath: "/tmp/x.zip.part1")), .zip)
  }

  func testDetectFormatForRarNumberedParts() {
    XCTAssertEqual(
      ArchiveFormatDetector.detectFormat(from: URL(fileURLWithPath: "/tmp/x.r00")), .rar)
  }

  func testDetectFormatSplitVolumeStillSplit() {
    XCTAssertEqual(
      ArchiveFormatDetector.detectFormat(from: URL(fileURLWithPath: "/tmp/a.zip.001")), .split)
    XCTAssertEqual(
      ArchiveFormatDetector.detectFormat(from: URL(fileURLWithPath: "/tmp/a.001")), .split)
  }

  func testDetectFormatLooseSubstringNotMatched() {
    XCTAssertNil(
      ArchiveFormatDetector.detectFormat(from: URL(fileURLWithPath: "/tmp/report.zipnotes.txt")))
    XCTAssertNil(ArchiveFormatDetector.detectFormat(from: URL(fileURLWithPath: "/tmp/photo.jpg")))
  }

  // MARK: - ZIP encryption detection

  func testZipEncryptedFlagSet() throws {
    var header = Data([0x50, 0x4B, 0x03, 0x04])
    header.append(contentsOf: [0x14, 0x00, 0x01, 0x00])
    header.append(Data(repeating: 0, count: 22))
    let url = try makeTempFile(name: "enc.zip", contents: header)
    defer { cleanup([url]) }
    XCTAssertTrue(ArchiveFormatDetector.isZipEncrypted(url))
    XCTAssertEqual(ArchiveFormatDetector.isEncrypted(url: url, format: .zip), true)
  }

  func testZipPlainFlagUnset() throws {
    var header = Data([0x50, 0x4B, 0x03, 0x04])
    header.append(contentsOf: [0x14, 0x00, 0x00, 0x00])
    header.append(Data(repeating: 0, count: 22))
    let url = try makeTempFile(name: "plain.zip", contents: header)
    defer { cleanup([url]) }
    XCTAssertFalse(ArchiveFormatDetector.isZipEncrypted(url))
    XCTAssertEqual(ArchiveFormatDetector.isEncrypted(url: url, format: .zip), false)
  }

  // MARK: - 7Z encryption detection

  private func makeSevenZip(nextHeader: Data) -> Data {
    var data = Data([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])
    data.append(contentsOf: [0x00, 0x04])
    data.append(Data(repeating: 0, count: 4))
    var offsetValue: UInt64 = 0
    var sizeValue: UInt64 = UInt64(nextHeader.count)
    var offsetLE = Data(count: 8)
    withUnsafeBytes(of: &offsetValue) { offsetLE.replaceSubrange(0..<8, with: $0) }
    var sizeLE = Data(count: 8)
    withUnsafeBytes(of: &sizeValue) { sizeLE.replaceSubrange(0..<8, with: $0) }
    data.append(offsetLE)
    data.append(sizeLE)
    data.append(Data(repeating: 0, count: 4))
    data.append(nextHeader)
    return data
  }

  func testSevenZipEncodedHeaderDetectedAsEncrypted() throws {
    let url = try makeTempFile(name: "enc.7z", contents: makeSevenZip(nextHeader: Data([0x17])))
    defer { cleanup([url]) }
    XCTAssertEqual(ArchiveFormatDetector.isEncrypted(url: url, format: .sevenZip), true)
  }

  func testSevenZipPlainHeaderDetectedAsNotEncrypted() throws {
    let url = try makeTempFile(name: "plain.7z", contents: makeSevenZip(nextHeader: Data([0x01])))
    defer { cleanup([url]) }
    XCTAssertEqual(ArchiveFormatDetector.isEncrypted(url: url, format: .sevenZip), false)
  }

  func testUnknownFormatsReturnNil() {
    XCTAssertNil(
      ArchiveFormatDetector.isEncrypted(url: URL(fileURLWithPath: "/tmp/a.rar"), format: .rar))
    XCTAssertNil(
      ArchiveFormatDetector.isEncrypted(url: URL(fileURLWithPath: "/tmp/a.tgz"), format: .tarGz))
  }

  // MARK: - Error classification

  func testClassifyWrongPasswordFromUnarExit3() {
    let error = ServiceError.classify(
      tool: "unar", status: 3, stderr: "", stdout: "",
      sourceURL: URL(fileURLWithPath: "/tmp/a.7z"))
    guard case .wrongPassword = error else {
      return XCTFail("expected wrongPassword, got \(error)")
    }
  }

  func testClassifyWrongPasswordFromStderrPattern() {
    let error = ServiceError.classify(
      tool: "unzip", status: 5, stderr: "skipping: a.txt incorrect password", stdout: "",
      sourceURL: URL(fileURLWithPath: "/tmp/a.zip"))
    guard case .wrongPassword = error else {
      return XCTFail("expected wrongPassword, got \(error)")
    }
  }

  func testClassifyDiskFull() {
    let error = ServiceError.classify(
      tool: "tar", status: 2, stderr: "Cannot write: No space left on device", stdout: "",
      sourceURL: URL(fileURLWithPath: "/tmp/a.tgz"))
    guard case .extractionFailed = error else {
      return XCTFail("expected extractionFailed, got \(error)")
    }
  }

  func testClassifyFallsBackToProcessExit() {
    let error = ServiceError.classify(
      tool: "ditto", status: 9, stderr: "", stdout: "",
      sourceURL: URL(fileURLWithPath: "/tmp/a.zip"))
    guard case .processExit = error else {
      return XCTFail("expected processExit, got \(error)")
    }
  }

  // MARK: - BatchResult password-only failures

  func testHasPasswordFailuresOnlyTrue() {
    let result = BatchResult(
      successes: [],
      failures: [
        BatchResult.Failure(
          sourceURL: URL(fileURLWithPath: "/tmp/a.zip"), error: "bad", isPasswordError: true)
      ]
    )
    XCTAssertTrue(result.hasPasswordFailuresOnly)
  }

  func testHasPasswordFailuresOnlyFalseWithMixedFailures() {
    let url = URL(fileURLWithPath: "/tmp/a.zip")
    let result = BatchResult(
      successes: [],
      failures: [
        BatchResult.Failure(sourceURL: url, error: "bad", isPasswordError: true),
        BatchResult.Failure(sourceURL: url, error: "corrupt", isPasswordError: false),
      ]
    )
    XCTAssertFalse(result.hasPasswordFailuresOnly)
  }

  func testHasPasswordFailuresOnlyFalseWhenSomeSucceeded() {
    let url = URL(fileURLWithPath: "/tmp/a.zip")
    let success = ExtractionResult(
      sourceURL: url, destinationURL: url.deletingLastPathComponent(), format: .zip,
      fileCount: 1, duration: 0.1, bytesExtracted: 10)
    let result = BatchResult(
      successes: [success],
      failures: [
        BatchResult.Failure(sourceURL: url, error: "bad", isPasswordError: true)
      ]
    )
    XCTAssertFalse(result.hasPasswordFailuresOnly)
  }

  // MARK: - ViewModel retry wiring

  @MainActor
  func testRetryFailuresWithoutBatchResultDoesNothing() {
    let viewModel = DecompressViewModel()
    viewModel.retryFailures()
    XCTAssertTrue(viewModel.isIdle)
  }

  @MainActor
  func testAddFilesRejectsLooseExtensionMatches() {
    let viewModel = DecompressViewModel()
    viewModel.addFiles([
      URL(fileURLWithPath: "/tmp/report.zipnotes.txt"),
      URL(fileURLWithPath: "/tmp/real.zip"),
    ])
    XCTAssertEqual(viewModel.selectedURLs.count, 1)
    XCTAssertEqual(viewModel.selectedURLs.first?.lastPathComponent, "real.zip")
  }

  @MainActor
  func testClearFilesResetsPasswordError() {
    let viewModel = DecompressViewModel()
    viewModel.passwordError = "Incorrect password"
    viewModel.clearFiles()
    XCTAssertNil(viewModel.passwordError)
  }
}
