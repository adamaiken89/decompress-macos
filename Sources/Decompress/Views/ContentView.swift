import SwiftUI

struct ContentView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel
  @Environment(\.openWindow)
  private var openWindow

  var body: some View {
    if viewModel.launchedByFileOpen {
      LiteContentView()
        .fixedSize()
        .transition(.scale.combined(with: .opacity))
    } else {
      fullContent
        .frame(minWidth: 560, minHeight: 620)
    }
  }

  private var fullContent: some View {
    VStack(spacing: DesignConstants.Spacing.zero) {
      switch viewModel.extractionState {
      case .idle:
        DragDropView()
          .transition(.move(edge: .bottom).combined(with: .opacity))

      case .preparing, .extracting:
        ExtractionProgressView()
          .transition(.scale.combined(with: .opacity))

      case .browsing:
        ArchiveContentView()
          .transition(.move(edge: .trailing).combined(with: .opacity))

      case .completed(let batchResult):
        ExtractionCompletedView(batchResult: batchResult)
          .transition(.scale(scale: 0.95).combined(with: .opacity))

      case .failed(let message):
        ExtractionFailedView(message: message)
          .transition(.scale(scale: 0.95).combined(with: .opacity))
      }
    }
    .padding(DesignConstants.Padding.horizontalTight)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.extractionState)
    .onChange(of: viewModel.extractionState) { _, newState in
      if case .browsing = newState {
        if let window = NSApp.mainWindow {
          let newSize = NSSize(width: 1200, height: 1400)
          if window.frame.size.width < newSize.width || window.frame.size.height < newSize.height {
            window.setFrame(
              NSRect(
                x: window.frame.origin.x,
                y: window.frame.origin.y - (newSize.height - window.frame.size.height),
                width: newSize.width,
                height: newSize.height
              ),
              display: true,
              animate: true
            )
          }
        }
      }
    }
    .onChange(of: viewModel.showHelp) { _, newValue in
      if newValue {
        openWindow(id: "help")
        viewModel.showHelp = false
      }
    }
    .toolbar {
      ToolbarItem {
        Button(action: { viewModel.showHelp = true }) {
          Label(loc("Help"), systemImage: "questionmark.circle")
        }
        .help(loc("Open usage guide"))
      }
    }
  }
}
