import SwiftUI

struct PasswordPromptView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel

  var body: some View {
    HStack(spacing: DesignConstants.Spacing.groupBox) {
      Image(systemName: "key.fill")
        .foregroundStyle(AppColors.ppKeyIcon)
        .font(DesignConstants.Font.headline)
        .accessibilityHidden(true)

      SecureField(loc("Enter password"), text: Bindable(viewModel).password)
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
        .accessibilityLabel(loc("Archive password"))
        .accessibilityHint(loc("Enter the password for the encrypted archive"))
    }
    .padding(DesignConstants.Padding.card)
    .cardBackground()
    .font(DesignConstants.Font.body)
  }
}
