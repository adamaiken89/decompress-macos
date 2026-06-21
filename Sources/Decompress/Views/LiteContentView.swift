import SwiftUI

struct LiteContentView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel

  var body: some View {
    VStack(spacing: DesignConstants.Spacing.zero) {
      switch viewModel.extractionState {
      case .idle:
        if viewModel.isPasswordProtected {
          litePasswordView
        } else {
          litePreparingView
        }

      case .preparing, .extracting:
        liteProgressView

      case .browsing:
        liteProgressView

      case .completed(let batchResult):
        liteCompletedView(batchResult)

      case .failed(let message):
        liteFailedView(message)
      }
    }
    .padding(.vertical, 16)
  }

  private var litePasswordView: some View {
    VStack(spacing: 12) {
      VStack(spacing: 6) {
        Image(systemName: "doc.zipper")
          .font(.system(size: DesignConstants.FontSize.smallIcon))
          .foregroundStyle(AppColors.dzIconDefault)

        Text(viewModel.selectedURLs.first?.lastPathComponent ?? "")
          .font(DesignConstants.Font.subheadline)
          .fontWeight(.medium)
          .lineLimit(1)

        Text(loc("Password is required for this archive"))
          .font(DesignConstants.Font.caption)
          .foregroundStyle(AppColors.dzSubtitle)
      }

      HStack(spacing: 8) {
        Image(systemName: "key.fill")
          .foregroundStyle(AppColors.ppKeyIcon)
        SecureField(loc("Enter password"), text: Bindable(viewModel).password)
          .textFieldStyle(.roundedBorder)
          .labelsHidden()
      }
      .padding(DesignConstants.Padding.extraCompact)
      .cardBackground()
      .frame(width: DesignConstants.Layout.passwordCardWidth)

      Button(loc("Extract All")) {
        viewModel.extractAll()
      }
      .primaryButton()
      .keyboardShortcut(.return)
      .disabled(viewModel.password.isEmpty)
    }
  }

  private var litePreparingView: some View {
    VStack(spacing: 10) {
      ProgressView()
        .scaleEffect(DesignConstants.Layout.spinnerScale)
      Text(loc("Preparing..."))
        .font(DesignConstants.Font.subheadline)
        .fontWeight(.medium)
    }
  }

  private var liteProgressView: some View {
    VStack(spacing: 10) {
      if case .extracting(let progress, let currentFile, _, _) = viewModel.extractionState {
        VStack(spacing: 10) {
          Text(loc("Extracting..."))
            .font(DesignConstants.Font.subheadline)
            .fontWeight(.medium)

          ProgressView(value: progress, total: 1.0)
            .frame(width: DesignConstants.Layout.progressBarWidth)
            .tint(AppColors.epProgressTint)

          Text(currentFile)
            .font(DesignConstants.Font.caption)
            .foregroundStyle(AppColors.epFileName)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      } else {
        ProgressView()
          .scaleEffect(DesignConstants.Layout.spinnerScale)
        Text(loc("Extracting..."))
          .font(DesignConstants.Font.subheadline)
          .fontWeight(.medium)
      }
    }
  }

  private func liteCompletedView(_ batchResult: BatchResult) -> some View {
    VStack(spacing: 10) {
      if batchResult.allSucceeded {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: DesignConstants.FontSize.statusIcon))
          .foregroundStyle(AppColors.ecSuccessIcon)
        Text(loc("Extraction Complete"))
          .font(DesignConstants.Font.subheadline)
          .fontWeight(.semibold)
      } else {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: DesignConstants.FontSize.statusIcon))
          .foregroundStyle(AppColors.efIcon)
        Text(loc("Extraction Failed"))
          .font(DesignConstants.Font.subheadline)
          .fontWeight(.semibold)

        if let failure = batchResult.failures.first {
          Text(failure.error)
            .font(DesignConstants.Font.caption)
            .foregroundStyle(AppColors.efMessage)
            .multilineTextAlignment(.center)
            .padding(DesignConstants.Padding.extraCompact)
            .cardBackground()
            .frame(maxWidth: DesignConstants.Layout.messageMaxWidth)
        }

        Button(loc("Try Again")) {
          viewModel.reset()
        }
        .primaryButton()
        .keyboardShortcut(.return)
      }
    }
  }

  private func liteFailedView(_ message: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "xmark.circle.fill")
        .font(.system(size: DesignConstants.FontSize.statusIcon))
        .foregroundStyle(AppColors.efIcon)

      Text(loc("Extraction Failed"))
        .font(DesignConstants.Font.subheadline)
        .fontWeight(.semibold)

      Text(message)
        .font(DesignConstants.Font.caption)
        .foregroundStyle(AppColors.efMessage)
        .multilineTextAlignment(.center)
        .padding(DesignConstants.Padding.extraCompact)
        .cardBackground()
        .frame(maxWidth: DesignConstants.Layout.messageMaxWidth)

      Button(loc("Try Again")) {
        viewModel.reset()
      }
      .primaryButton()
      .keyboardShortcut(.return)
    }
  }
}
