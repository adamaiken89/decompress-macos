import SwiftUI

struct PasswordPromptView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel
  @State private var showPassword = false
  @FocusState private var isFieldFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: DesignConstants.Spacing.labelPair) {
      HStack(spacing: DesignConstants.Spacing.groupBox) {
        Image(systemName: "key.fill")
          .foregroundStyle(AppColors.ppKeyIcon)
          .font(DesignConstants.Font.headline)
          .accessibilityHidden(true)

        Group {
          if showPassword {
            TextField(loc("Enter password"), text: Bindable(viewModel).password.value)
          } else {
            SecureField(loc("Enter password"), text: Bindable(viewModel).password.value)
          }
        }
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
        .focused($isFieldFocused)
        .onAppear { isFieldFocused = true }
        .submitLabel(.go)
        .accessibilityLabel(loc("Archive password"))
        .accessibilityHint(loc("Enter the password for the encrypted archive"))

        Button {
          showPassword.toggle()
        } label: {
          Image(systemName: showPassword ? "eye.slash" : "eye")
            .foregroundStyle(AppColors.dzSubtitle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showPassword ? loc("Hide password") : loc("Show password"))
      }

      if let error = viewModel.password.error {
        HStack(spacing: DesignConstants.Spacing.relatedContent) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(DesignConstants.Font.caption)
          Text(error)
            .font(DesignConstants.Font.caption)
        }
        .foregroundStyle(AppColors.efMessage)
        .accessibilityElement(children: .combine)
      }
    }
    .padding(DesignConstants.Padding.card)
    .cardBackground()
    .font(DesignConstants.Font.body)
  }
}
