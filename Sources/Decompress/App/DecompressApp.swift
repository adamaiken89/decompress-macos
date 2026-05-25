import SwiftUI

@main
struct DecompressApp: App {
    @State private var viewModel = DecompressViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 520, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open…") {
                    viewModel.showFilePicker = true
                }
                .keyboardShortcut("o")

                Button("Extract All") {
                    viewModel.extractAll()
                }
                .keyboardShortcut("e")
                .disabled(viewModel.selectedURLs.isEmpty)
            }

            CommandGroup(replacing: .help) {
                Button("Decompress Help") {
                    viewModel.showHelp = true
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        Window("Decompress Help", id: "help") {
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
