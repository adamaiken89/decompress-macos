import SwiftUI

struct ExtractionProgressView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel

  @State private var now = Date()
  @State private var pulsePhase = false

  var body: some View {
    VStack(spacing: DesignConstants.Spacing.pageWide) {
      Spacer()

      if case .preparing = viewModel.extractionState {
        VStack(spacing: DesignConstants.Spacing.pageSection) {
          ProgressView()
            .scaleEffect(1.2)
          Text(loc("Preparing..."))
            .font(DesignConstants.Font.title2)
            .fontWeight(.medium)
        }
        .transition(.opacity)
      }

      if case .extracting(let progress, let currentFile, let archiveIndex, let totalArchives) =
        viewModel.extractionState
      {
        VStack(spacing: DesignConstants.Spacing.progressContent) {
          Text(loc("Extracting..."))
            .font(DesignConstants.Font.title2)
            .fontWeight(.medium)

          ProgressView(value: progress, total: 1.0)
            .frame(maxWidth: 360)
            .tint(AppColors.epProgressTint)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
            .accessibilityLabel(loc("Extraction progress"))

          Text(currentFile)
            .font(DesignConstants.Font.body)
            .foregroundStyle(AppColors.epFileName)
            .lineLimit(1)
            .truncationMode(.middle)
            .opacity(pulsePhase ? 1 : 0.7)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulsePhase)
            .accessibilityLabel(String(format: loc("Current file: %@"), currentFile))

          HStack(spacing: DesignConstants.Spacing.progressContent) {
            if let startTime = viewModel.extractionStartTime {
              let elapsed = now.timeIntervalSince(startTime)
              Label(formattedDuration(elapsed), systemImage: "clock")
                .font(DesignConstants.Font.subheadline)
                .foregroundStyle(AppColors.epDetail)
            }

            if totalArchives > 1 {
              Text(String(format: loc("Archive %d of %d"), archiveIndex + 1, totalArchives))
                .font(DesignConstants.Font.subheadline)
                .foregroundStyle(AppColors.epDetail)
                .monospacedDigit()
            }
          }
        }
        .padding(DesignConstants.Padding.progressCard)
        .cardBackground(cornerRadius: 14)
        .frame(maxWidth: 400)
        .transition(.scale.combined(with: .opacity))
      }

      if viewModel.canCancel {
        Button(loc("Cancel"), role: .cancel) {
          viewModel.cancelExtraction()
        }
        .secondaryButton()
        .keyboardShortcut(.escape)
      }

      if viewModel.queueCount > 0 {
        HStack(spacing: DesignConstants.Spacing.relatedContent) {
          Image(systemName: "rectangle.stack.badge.plus")
            .foregroundStyle(AppColors.epDetail)
          Text(String(format: loc("%d more in queue"), viewModel.queueCount))
            .font(DesignConstants.Font.subheadline)
            .foregroundStyle(AppColors.epDetail)
        }
        .padding(.top, DesignConstants.Spacing.relatedContent)
        .accessibilityLabel(
          String(format: loc("%d archives waiting in queue"), viewModel.queueCount))
      }

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { input in
      now = input
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
        pulsePhase = true
      }
    }
  }

  private func formattedDuration(_ duration: TimeInterval) -> String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    return formatter.string(from: duration) ?? "0s"
  }
}
