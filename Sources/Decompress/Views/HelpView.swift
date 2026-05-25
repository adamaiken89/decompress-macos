import SwiftUI

struct HelpView: View {
  @Environment(\.dismissWindow)
  private var dismissWindow

  var body: some View {
    TabView {
      usageTab
        .tabItem { Label(loc("Usage"), systemImage: "book") }

      formatsTab
        .tabItem { Label(loc("Supported Formats"), systemImage: "doc.zipper") }

      tipsTab
        .tabItem { Label(loc("Tips"), systemImage: "lightbulb") }
    }
    .padding(.top, DesignConstants.Padding.topTight)
    .frame(minWidth: 500, minHeight: 400)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(loc("Done")) { dismissWindow(id: "help") }
          .keyboardShortcut(.escape)
      }
    }
  }

  private var usageTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignConstants.Spacing.pageSection) {
        section(loc("How to extract archives")) {
          step("1", loc("Drop archives onto the main window, or click Select Files to browse."))
          step("2", loc("If the archive is password-protected, enter the password."))
          step("3", loc("Choose whether to extract in place."))
          step("4", loc("Click Extract All. Progress is shown during extraction."))
          step("5", loc("When complete, click Reveal in Finder to locate files."))
        }

        section(loc("Adding files")) {
          bullet(loc("Drag and drop one or more archive files onto the drop zone."))
          bullet(loc("Click Select Files to use the system file picker."))
          bullet(loc("Supported formats are detected automatically by extension and magic bytes."))
        }

        section(loc("Extraction behavior")) {
          bullet(
            loc(
              "By default, each archive extracts into a subfolder named after the archive (e.g., project.zip → project/)."
            ))
          bullet(loc("Enable Extract in place to extract directly into the source directory."))
          bullet(loc("In Settings, you can choose a custom default output directory."))
          bullet(loc("Enable Move archive to Trash to clean up the original after extraction."))
        }
      }
      .frame(maxWidth: 520, alignment: .leading)
    }
    .padding()
  }

  private var formatsTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignConstants.Spacing.sectionHeader) {
        ForEach(ArchiveFormat.allCases, id: \.self) { format in
          HStack(spacing: DesignConstants.Spacing.sectionGroup) {
            Image(systemName: formatIcon(for: format))
              .foregroundStyle(AppColors.hvFormatIcon)
              .frame(width: 20)
              .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignConstants.Spacing.rowContent) {
              Text(format.displayName)
                .font(DesignConstants.Font.headline)
                .fontWeight(.medium)

              Text(format.fileExtensions.joined(separator: ", "))
                .font(DesignConstants.Font.subheadline)
                .foregroundStyle(AppColors.hvFormatExtension)
            }

            Spacer()

            Text(magicDescription(for: format))
              .font(DesignConstants.Font.caption)
              .foregroundStyle(AppColors.hvFormatMagic)
          }
          .padding(.vertical, DesignConstants.Padding.verticalTight)
          .padding(.horizontal, DesignConstants.Padding.horizontalDefault)
          .cardBackground(cornerRadius: 8)
        }
      }
      .frame(maxWidth: 520, alignment: .leading)
    }
    .padding()
  }

  private var tipsTab: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignConstants.Spacing.pageSection) {
        section(loc("Keyboard shortcuts")) {
          shortcut(loc("Cmd+O"), loc("Open file picker"))
          shortcut(loc("Cmd+E"), loc("Extract all selected archives"))
          shortcut(loc("Cmd+Shift+O"), loc("Open Settings"))
          shortcut(loc("Cmd+?"), loc("Open this help window"))
        }

        section(loc("Troubleshooting")) {
          bullet(loc("If extraction fails, check that the archive is not corrupted."))
          bullet(
            loc(
              "Password-protected ZIP archives require the correct password and use /usr/bin/unzip."
            ))
          bullet(loc("7Z and RAR archives use /usr/bin/unar for extraction."))
          bullet(loc("For very large archives, extraction may take a few moments."))
          bullet(
            loc(
              "If a format is not detected, try renaming the file to include a standard extension."
            ))
          bullet(
            loc(
              "For split archives (e.g., .part01.rar, .7z.001), only the first part is needed — additional parts are automatically detected."
            ))
        }

        section(loc("About Decompress")) {
          VStack(alignment: .leading, spacing: DesignConstants.Spacing.relatedContent) {
            Text(
              loc(
                "Decompress is a native macOS archive extraction utility. It uses system tools (ditto, tar, gunzip, bunzip2, unxz, unar, unzip) to handle a wide range of archive formats without any external dependencies."
              )
            )
            .font(DesignConstants.Font.body)
            .foregroundStyle(AppColors.hvDescription)
            .fixedSize(horizontal: false, vertical: true)

            Text("Version \(AppVersion.version) (\(AppVersion.build))")
              .font(DesignConstants.Font.subheadline)
              .foregroundStyle(AppColors.hvVersion)
          }
          .padding(DesignConstants.Padding.section)
          .cardBackground()
        }
      }
      .frame(maxWidth: 520, alignment: .leading)
    }
    .padding()
  }

  private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: DesignConstants.Spacing.groupBox) {
      Text(title)
        .font(DesignConstants.Font.title3)
      content()
    }
    .padding(DesignConstants.Padding.section)
    .cardBackground()
  }

  private func step(_ number: String, _ text: String) -> some View {
    HStack(alignment: .top, spacing: DesignConstants.Spacing.groupBox) {
      Text(number)
        .font(DesignConstants.Font.subheadline)
        .fontWeight(.bold)

      Text(text)
        .font(DesignConstants.Font.body)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func bullet(_ text: String) -> some View {
    HStack(alignment: .top, spacing: DesignConstants.Spacing.relatedContent) {
      Text("•")
        .foregroundStyle(AppColors.hvBullet)
      Text(text)
        .font(DesignConstants.Font.body)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func shortcut(_ key: String, _ description: String) -> some View {
    HStack(spacing: DesignConstants.Spacing.groupBox) {
      Text(key)
        .font(DesignConstants.Font.subheadline)
        .fontWeight(.medium)
        .fontDesign(.monospaced)

      Text(description)
        .font(DesignConstants.Font.body)
      Spacer()
    }
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

  private func magicDescription(for format: ArchiveFormat) -> String {
    format.magicBytes.isEmpty
      ? loc("no magic bytes")
      : String(
        format: loc("magic: %@"), format.magicBytes.map { $0.hexString }.joined(separator: ", "))
  }
}

extension Data {
  var hexString: String {
    map { String(format: "%02X", $0) }.joined()
  }
}
