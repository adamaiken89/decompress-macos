import SwiftUI

struct ExtractionFailedView: View {
  let message: String

  @Environment(DecompressViewModel.self)
  private var viewModel

  var body: some View {
    VStack(spacing: DesignConstants.Spacing.pageSection) {
      Spacer()

      VStack(spacing: DesignConstants.Spacing.progressContent) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 40))
          .foregroundStyle(AppColors.efIcon)
          .symbolEffect(.bounce, options: .speed(0.6))
          .accessibilityHidden(true)

        Text(loc("Extraction Failed"))
          .font(DesignConstants.Font.title2)
          .fontWeight(.semibold)
      }

      Text(message)
        .font(DesignConstants.Font.body)
        .foregroundStyle(AppColors.efMessage)
        .multilineTextAlignment(.center)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .padding(DesignConstants.Padding.group)
        .cardBackground()

      HStack(spacing: DesignConstants.Spacing.sectionGroup) {
        Button(loc("Retry")) {
          viewModel.reset()
        }
        .primaryButton()
        .keyboardShortcut(.return)

        if let sourceURL = viewModel.lastFailedSourceURL {
          Button(loc("Trash")) {
            try? FileManager.default.trashItem(at: sourceURL, resultingItemURL: nil)
            viewModel.reset()
          }
          .secondaryButton()
          .keyboardShortcut(.delete, modifiers: .command)
        }
      }

      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(String(format: loc("Extraction failed: %@"), message))
  }
}
