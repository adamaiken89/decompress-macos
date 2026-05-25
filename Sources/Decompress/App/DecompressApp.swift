import SwiftUI

@main
struct DecompressApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate
  @State private var viewModel = DecompressViewModel.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(viewModel)
        .windowVisualEffect()
        .frame(minWidth: 560, minHeight: 620)
    }
    .windowResizability(.contentMinSize)
    .commands {
      CommandGroup(after: .newItem) {
        Button(loc("Open...")) {
          viewModel.showFilePicker = true
        }
        .keyboardShortcut("o")

        Button(loc("Extract All")) {
          viewModel.extractAll()
        }
        .keyboardShortcut("e")
        .disabled(viewModel.selectedURLs.isEmpty)
      }

      CommandGroup(replacing: .appInfo) {
        Button(loc("About Decompress")) {
          NSApplication.shared.orderFrontStandardAboutPanel(nil)
        }
      }

      CommandGroup(replacing: .help) {
        Button(loc("Decompress Help")) {
          viewModel.showHelp = true
        }
        .keyboardShortcut("?", modifiers: .command)
      }
    }

    Window(loc("Decompress Help"), id: "help") {
      HelpView()
    }
    .windowResizability(.contentMinSize)
    .defaultPosition(.center)

    Settings {
      SettingsView()
        .environment(viewModel)
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func application(_ application: NSApplication, open urls: [URL]) {
    DecompressViewModel.shared.openFiles(urls)
  }
}
