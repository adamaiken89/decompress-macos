import SwiftUI

struct SettingsView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel

  var body: some View {
    TabView {
      generalTab
        .tabItem { Label(loc("General"), systemImage: "gear") }

      formatsTab
        .tabItem { Label(loc("Formats"), systemImage: "doc.zipper") }
    }
    .frame(minWidth: 500, minHeight: 480)
  }

  private var generalTab: some View {
    Form {
      Section {
        Toggle(
          loc("Extract to source directory by default"),
          isOn: Bindable(viewModel).autoExtractToSourceDir
        )
        .help(
          loc("When enabled, archives are extracted into the same folder as the archive source"))

        Toggle(
          loc("Move archive to Trash after extraction"),
          isOn: Bindable(viewModel).deleteArchiveAfterExtraction
        )
        .help(loc("Archives will be moved to Trash after successful extraction"))
      }

      Section {
        GroupBox {
          VStack(alignment: .leading, spacing: DesignConstants.Spacing.groupBox) {
            HStack(alignment: .firstTextBaseline) {
              Text(loc("Default output location"))
                .font(DesignConstants.Font.body)
              Spacer()
            }

            if viewModel.autoExtractToSourceDir {
              HStack {
                Image(systemName: "folder")
                  .foregroundStyle(AppColors.stFolderIcon)
                  .font(DesignConstants.Font.subheadline)
                Text(loc("Same as source"))
                  .foregroundStyle(AppColors.stFolderLabel)
                  .font(DesignConstants.Font.body)
              }
            } else {
              HStack {
                Image(systemName: "folder")
                  .foregroundStyle(AppColors.stFolderIcon)
                  .font(DesignConstants.Font.subheadline)
                Text(viewModel.outputDirectoryURL?.path ?? loc("Not set"))
                  .font(DesignConstants.Font.body)
                  .foregroundStyle(AppColors.stFolderLabel)
                  .lineLimit(1)
                  .truncationMode(.middle)
              }
            }

            if !viewModel.autoExtractToSourceDir {
              Button(loc("Choose...")) {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.canCreateDirectories = true
                panel.message = loc("Select default extraction directory")
                panel.begin { response in
                  if response == .OK {
                    viewModel.outputDirectoryURL = panel.url
                  }
                }
              }
              .secondaryButton()
            }

            if viewModel.autoExtractToSourceDir {
              Text(loc("Turn off \"Extract to source directory\" to choose a custom location."))
                .font(DesignConstants.Font.subheadline)
                .foregroundStyle(AppColors.stHint)
            }
          }
          .padding(DesignConstants.Padding.card)
        }
        .cardBackground()
      }
      .disabled(viewModel.autoExtractToSourceDir)
    }
    .padding(DesignConstants.Padding.settingsTab)
  }

  private var formatsTab: some View {
    List(ArchiveFormat.allCases, id: \.self) { format in
      HStack(spacing: DesignConstants.Spacing.sectionGroup) {
        Image(systemName: formatIcon(for: format))
          .foregroundStyle(AppColors.stFormatIcon)
          .frame(width: 20)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: DesignConstants.Spacing.labelPair) {
          Text(format.displayName)
            .font(DesignConstants.Font.headline)
            .fontWeight(.medium)

          Text(format.fileExtensions.joined(separator: ", "))
            .font(DesignConstants.Font.subheadline)
            .foregroundStyle(AppColors.stFormatExtension)
        }

        Spacer()
      }
      .padding(.vertical, DesignConstants.Padding.verticalMinimum)
    }
    .padding(DesignConstants.Padding.settingsTab)
  }

  private func formatIcon(for format: ArchiveFormat) -> String {
    switch format {
    case .zip: "doc.zipper"
    case .tar, .tarGz, .tarBz2, .tarXz: "archivebox"
    case .gzip, .bzip2, .xz: "doc.compress"
    case .sevenZip: "archivebox"
    case .rar: "doc.zipper"
    case .split: "doc.badge.gearshape"
    }
  }
}
