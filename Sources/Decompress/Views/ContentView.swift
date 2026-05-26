import SwiftUI

struct ContentView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel
    @Environment(\.openWindow)
    private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.extractionState {
            case .idle:
                DragDropView()

            case .preparing, .extracting:
                ExtractionProgressView()

            case .completed(let result):
                ExtractionCompletedView(result: result)

            case .failed(let message):
                ExtractionFailedView(message: message)
            }
        }
        .padding()
        .onChange(of: viewModel.showHelp) { _, newValue in
            if newValue {
                openWindow(id: "help")
                viewModel.showHelp = false
            }
        }
        .toolbar {
            ToolbarItemGroup {
                if !viewModel.isIdle {
                    Button("Clear", systemImage: "xmark.circle") {
                        viewModel.reset()
                    }
                    .help("Reset to start over")
                    .disabled(viewModel.isBusy)
                }
            }

            ToolbarItem {
                Button("Help", systemImage: "questionmark.circle") {
                    viewModel.showHelp = true
                }
                .help("Open usage guide")
            }
        }
    }
}
