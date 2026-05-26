import SwiftUI

struct ExtractionFailedView: View {
    let message: String

    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

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
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button("Try Again") {
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)

                if let sourceURL = viewModel.lastFailedSourceURL {
                    Button("Move to Trash") {
                        try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
                        viewModel.reset()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.delete, modifiers: .command)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Extraction failed: \(message)")
    }
}
