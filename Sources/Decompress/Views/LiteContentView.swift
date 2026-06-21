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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var litePasswordView: some View {
    VStack(spacing: DesignConstants.Spacing.pageSection) {
      Spacer()

      VStack(spacing: DesignConstants.Spacing.progressContent) {
        Image(systemName: "doc.zipper")
          .font(.system(size: 32))
          .foregroundStyle(AppColors.dzIconDefault)

        Text(viewModel.selectedURLs.first?.lastPathComponent ?? "")
          .font(DesignConstants.Font.title3)
          .fontWeight(.medium)
          .lineLimit(1)

        Text(loc("Password is required for this archive"))
          .font(DesignConstants.Font.subheadline)
          .foregroundStyle(AppColors.dzSubtitle)
      }

      HStack(spacing: DesignConstants.Spacing.groupBox) {
        Image(systemName: "key.fill")
          .foregroundStyle(AppColors.ppKeyIcon)
        SecureField(loc("Enter password"), text: Bindable(viewModel).password)
          .textFieldStyle(.roundedBorder)
          .labelsHidden()
      }
      .padding(DesignConstants.Padding.card)
      .cardBackground()
      .frame(maxWidth: 300)

      Button(loc("Extract All")) {
        viewModel.extractAll()
      }
      .primaryButton()
      .keyboardShortcut(.return)
      .disabled(viewModel.password.isEmpty)

      Spacer()
    }
  }

  private var litePreparingView: some View {
    VStack(spacing: DesignConstants.Spacing.pageSection) {
      Spacer()
      ProgressView()
        .scaleEffect(1.2)
      Text(loc("Preparing..."))
        .font(DesignConstants.Font.title2)
        .fontWeight(.medium)
      Spacer()
    }
  }

  private var liteProgressView: some View {
    VStack(spacing: DesignConstants.Spacing.progressContent) {
      Spacer()

      if case .extracting(let progress, let currentFile, _, _) = viewModel.extractionState {
        VStack(spacing: DesignConstants.Spacing.progressContent) {
          Text(loc("Extracting..."))
            .font(DesignConstants.Font.title2)
            .fontWeight(.medium)

          ProgressView(value: progress, total: 1.0)
            .frame(maxWidth: 300)
            .tint(AppColors.epProgressTint)

          Text(currentFile)
            .font(DesignConstants.Font.body)
            .foregroundStyle(AppColors.epFileName)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      } else {
        ProgressView()
          .scaleEffect(1.2)
        Text(loc("Extracting..."))
          .font(DesignConstants.Font.title2)
          .fontWeight(.medium)
      }

      Spacer()
    }
  }

  private func liteCompletedView(_ batchResult: BatchResult) -> some View {
    VStack(spacing: DesignConstants.Spacing.pageSection) {
      Spacer()

      if batchResult.allSucceeded {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 40))
          .foregroundStyle(AppColors.ecSuccessIcon)
        Text(loc("Extraction Complete"))
          .font(DesignConstants.Font.title2)
          .fontWeight(.semibold)
      } else {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 40))
          .foregroundStyle(AppColors.efIcon)
        Text(loc("Extraction Failed"))
          .font(DesignConstants.Font.title2)
          .fontWeight(.semibold)

        if let failure = batchResult.failures.first {
          Text(failure.error)
            .font(DesignConstants.Font.body)
            .foregroundStyle(AppColors.efMessage)
            .multilineTextAlignment(.center)
            .padding(DesignConstants.Padding.group)
            .cardBackground()
            .frame(maxWidth: 400)
        }

        Button(loc("Try Again")) {
          viewModel.reset()
        }
        .primaryButton()
        .keyboardShortcut(.return)
      }

      Spacer()
    }
  }

  private func liteFailedView(_ message: String) -> some View {
    VStack(spacing: DesignConstants.Spacing.pageSection) {
      Spacer()

      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 40))
        .foregroundStyle(AppColors.efIcon)

      Text(loc("Extraction Failed"))
        .font(DesignConstants.Font.title2)
        .fontWeight(.semibold)

      Text(message)
        .font(DesignConstants.Font.body)
        .foregroundStyle(AppColors.efMessage)
        .multilineTextAlignment(.center)
        .padding(DesignConstants.Padding.group)
        .cardBackground()
        .frame(maxWidth: 400)

      Button(loc("Try Again")) {
        viewModel.reset()
      }
      .primaryButton()
      .keyboardShortcut(.return)

      Spacer()
    }
  }
}
