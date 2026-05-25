import SwiftUI

@main
struct DecompressApp: App {
    @State private var viewModel = DecompressViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 500, minHeight: 400)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environment(viewModel)
        }
    }
}
