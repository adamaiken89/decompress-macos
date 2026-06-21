import SwiftUI

struct ExtractionCompletedView: View {
  let batchResult: BatchResult

  @Environment(DecompressViewModel.self)
  private var viewModel

  var body: some View {
    VStack(spacing: DesignConstants.Spacing.pageSection) {
      statusHeader

      ScrollView {
        VStack(alignment: .leading, spacing: DesignConstants.Spacing.sectionGroup) {
          if !batchResult.successes.isEmpty {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.relatedContent) {
              ForEach(Array(batchResult.successes.enumerated()), id: \.element.sourceURL) {
                _, result in
                successRow(result)
              }
            }
          }

          if !batchResult.failures.isEmpty {
            VStack(alignment: .leading, spacing: DesignConstants.Spacing.relatedContent) {
              Text(loc("Failed"))
                .font(DesignConstants.Font.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.ecSectionFailedTitle)
                .padding(.horizontal, DesignConstants.Padding.horizontalExtraTight)

              ForEach(Array(batchResult.failures.enumerated()), id: \.element.sourceURL) {
                _, failure in
                failureRow(failure)
              }
            }
          }
        }
        .padding(.horizontal, DesignConstants.Padding.horizontalTight)
      }

      actionButtons
    }
    .padding(DesignConstants.Padding.group)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(loc("Extraction completed"))
  }

  private var statusHeader: some View {
    HStack(spacing: DesignConstants.Spacing.sectionGroup) {
      statusIcon
        .font(.system(size: 28))
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: DesignConstants.Padding.verticalMinimum) {
        Text(statusTitle)
          .font(DesignConstants.Font.title3)
          .fontWeight(.semibold)
          .lineLimit(1)

        Text(
          String(
            format: loc("%d of %d files extracted successfully"),
            batchResult.successes.count,
            batchResult.totalCount
          )
        )
        .font(DesignConstants.Font.subheadline)
        .foregroundStyle(AppColors.ecSummaryText)
        .monospacedDigit()
        .lineLimit(1)
      }

      Spacer()
    }
    .padding(DesignConstants.Padding.card)
    .sectionBackground()
  }

  private var statusIcon: some View {
    Group {
      if batchResult.allSucceeded {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(AppColors.ecSuccessIcon)
      } else if batchResult.successes.isEmpty {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(AppColors.ecFailureIcon)
      } else {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(AppColors.ecWarningIcon)
      }
    }
  }

  private var statusTitle: String {
    if batchResult.allSucceeded {
      loc("Extraction Complete")
    } else if batchResult.successes.isEmpty {
      loc("Extraction Failed")
    } else {
      loc("Extraction Complete with Errors")
    }
  }

  private func successRow(_ result: ExtractionResult) -> some View {
    HStack(spacing: DesignConstants.Spacing.sectionGroup) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(AppColors.ecSuccessIcon)
        .font(DesignConstants.Font.body)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: DesignConstants.Padding.verticalMinimum) {
        Text(result.sourceURL.lastPathComponent)
          .font(DesignConstants.Font.body)
          .fontWeight(.medium)
          .lineLimit(1)

        HStack(spacing: DesignConstants.Spacing.groupBox) {
          Label(result.format.displayName, systemImage: "doc.zipper")
          Label(result.formattedSize, systemImage: "externaldrive")
          if let duration = result.formattedDuration {
            Label(duration, systemImage: "clock")
          }
        }
        .font(DesignConstants.Font.caption)
        .foregroundStyle(AppColors.ecFileDetail)
      }

      Spacer()

      Button(loc("Reveal")) {
        NSWorkspace.shared.selectFile(
          result.destinationURL.path,
          inFileViewerRootedAtPath: result.destinationURL
            .deletingLastPathComponent().path
        )
      }
      .secondaryButton()
      .controlSize(.small)
    }
    .padding(DesignConstants.Padding.card)
    .cardBackground()
  }

  private func failureRow(_ failure: BatchResult.Failure) -> some View {
    HStack(spacing: DesignConstants.Spacing.sectionGroup) {
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(AppColors.ecFailureIcon)
        .font(DesignConstants.Font.body)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: DesignConstants.Padding.verticalMinimum) {
        Text(failure.sourceURL.lastPathComponent)
          .font(DesignConstants.Font.body)
          .fontWeight(.medium)
          .lineLimit(1)

        Text(failure.error)
          .font(DesignConstants.Font.caption)
          .foregroundStyle(AppColors.ecSectionTitle)
          .textSelection(.enabled)
          .lineLimit(2)
      }

      Spacer()

      Button(loc("Trash")) {
        try? FileManager.default.trashItem(at: failure.sourceURL, resultingItemURL: nil)
      }
      .secondaryButton()
      .controlSize(.small)
    }
    .padding(DesignConstants.Padding.card)
    .cardBackground()
  }

  private var actionButtons: some View {
    HStack(spacing: DesignConstants.Spacing.sectionGroup) {
      Button(loc("Back")) {
        viewModel.reset()
      }
      .secondaryButton()
      .keyboardShortcut(.escape)

      Spacer()

      Button(loc("Reveal")) {
        if let firstSuccess = batchResult.successes.first {
          NSWorkspace.shared.selectFile(
            firstSuccess.destinationURL.path,
            inFileViewerRootedAtPath: firstSuccess.destinationURL
              .deletingLastPathComponent().path
          )
        } else if let firstFailure = batchResult.failures.first {
          NSWorkspace.shared.selectFile(
            firstFailure.sourceURL.path,
            inFileViewerRootedAtPath: firstFailure.sourceURL
              .deletingLastPathComponent().path
          )
        }
      }
      .primaryButton()
      .keyboardShortcut("r")
      .disabled(batchResult.totalCount == 0)

      if !batchResult.allSucceeded {
        Button(loc("Retry")) {
          viewModel.reset()
        }
        .primaryButton()
        .keyboardShortcut(.return)
      }

      Button(loc("New")) {
        viewModel.reset()
      }
      .primaryButton()
      .keyboardShortcut("n")
    }
  }
}
