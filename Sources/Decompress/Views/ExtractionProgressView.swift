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

            if case .extracting(let progress, let currentFile) = viewModel.extractionState {
                ProgressView(value: progress, total: 1.0)
                    .frame(maxWidth: 300)

                Text(currentFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
