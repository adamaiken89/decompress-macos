import SwiftUI

struct ContentView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel

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
        .toolbar {
            ToolbarItemGroup {
                if !viewModel.isIdle {
                    Button("Clear") {
                        viewModel.reset()
                    }
                }
            }
        }
    }
}

private struct ExtractionCompletedView: View {
    let result: ExtractionResult

    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Extraction Complete")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Label("Format: \(result.format.displayName)", systemImage: "doc.zipper")
                Label("Files: \(result.fileCount)", systemImage: "doc.on.doc")
                Label("Size: \(result.formattedSize)", systemImage: "externaldrive")
                Label("Duration: \(result.formattedDuration)", systemImage: "clock")
            }
            .font(.subheadline)

            HStack(spacing: 12) {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(
                        result.destinationURL.path,
                        inFileViewerRootedAtPath: result.destinationURL.deletingLastPathComponent().path
                    )
                }

                Button("Extract Another") {
                    viewModel.reset()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct ExtractionFailedView: View {
    let message: String

    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Extraction Failed")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
