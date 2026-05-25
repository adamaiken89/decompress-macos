import SwiftUI

struct PasswordPromptView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        VStack(spacing: 8) {
            Toggle(isOn: Bindable(viewModel).isPasswordProtected) {
                Label("Password required", systemImage: "lock")
            }
            .help("Enable if the archive is encrypted")

            if viewModel.isPasswordProtected {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                    SecureField("Enter password", text: Bindable(viewModel).password)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .accessibilityLabel("Archive password")
                        .accessibilityHint("Enter the password for the encrypted archive")
                }
                .padding(.leading, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .font(.caption)
    }
}
