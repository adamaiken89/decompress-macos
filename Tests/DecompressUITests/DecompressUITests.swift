import XCTest

@available(macOS 15, *)
final class DecompressUITests: XCTestCase {
  var app: XCUIApplication?

  override func setUpWithError() throws {
    continueAfterFailure = false
    let application = XCUIApplication()
    application.launch()
    app = application
  }

  override func tearDownWithError() throws {
    app = nil
  }

  func testAppLaunches() {
    guard let app else {
      XCTFail("App not launched")
      return
    }
    XCTAssertFalse(app.windows.isEmpty)
  }

  func testWindowTitle() {
    guard let app else {
      XCTFail("App not launched")
      return
    }
    let window = app.windows.firstMatch
    XCTAssertTrue(window.exists)
  }

  func testDragDropAreaExists() {
    guard let app else {
      XCTFail("App not launched")
      return
    }
    let dropArea = app.staticTexts["Drop archives here"]
    XCTAssertTrue(dropArea.waitForExistence(timeout: 2))
  }

  func testSelectFilesButtonExists() {
    guard let app else {
      XCTFail("App not launched")
      return
    }
    let button = app.buttons["Select Files"]
    XCTAssertTrue(button.waitForExistence(timeout: 2))
  }

  func testSettingsMenuExists() {
    guard let app else {
      XCTFail("App not launched")
      return
    }
    let menuBar = app.menuBars.firstMatch
    XCTAssertTrue(menuBar.exists)
  }
}
