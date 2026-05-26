import SwiftUI

struct ExtractionProgressView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Extracting...")
                .font(.title3)
                .fontWeight(.medium)

            if case .extracting(let progress, let currentFile, let archiveIndex, let totalArchives) = viewModel.extractionState {
                ProgressView(value: progress, total: 1.0)
                    .frame(maxWidth: 300)
                    .accessibilityLabel("Extraction progress")
                    .accessibilityValue("\(Int(progress * 100)) percent")

                Text(currentFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityLabel("Current file: \(currentFile)")

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                if totalArchives > 1 {
                    Text("Archive \(archiveIndex + 1) of \(totalArchives)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if viewModel.canCancel {
                Button("Cancel", role: .cancel) {
                    viewModel.cancelExtraction()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
