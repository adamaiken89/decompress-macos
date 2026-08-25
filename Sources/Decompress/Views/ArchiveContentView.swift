import SwiftUI

struct ArchiveContentView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel
  @State private var selectedPaths: [URL: Set<String>] = [:]

  var body: some View {
    VStack(spacing: DesignConstants.Spacing.sectionGroup) {
      header
        .padding(.horizontal, DesignConstants.Padding.horizontalTight)

      archiveList
        .frame(maxHeight: .infinity)

      if viewModel.password.isProtected {
        PasswordPromptView()
      }

      actionButtons
    }
    .padding(DesignConstants.Padding.group)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear(perform: initializeSelection)
    .background {
      Button("") { viewModel.backToFiles() }
        .keyboardShortcut(.leftArrow, modifiers: [])
        .hidden()
    }
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: DesignConstants.Padding.verticalMinimum) {
        Text(loc("Archive Contents"))
          .font(DesignConstants.Font.title3)
          .fontWeight(.semibold)
        Text(
          String(
            format: loc("%d archives, %d total files"),
            viewModel.archiveContents.count,
            viewModel.archiveContents.reduce(0) { $0 + $1.entries.count }
          )
        )
        .font(DesignConstants.Font.caption)
        .foregroundStyle(AppColors.acHeaderInfo)
      }
      Spacer()
    }
  }

  private var archiveList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignConstants.Spacing.sectionGroup) {
        ForEach(viewModel.archiveContents) { content in
          archiveSection(content)
        }
      }
    }
  }

  private func archiveSection(_ content: ArchiveContent) -> some View {
    VStack(alignment: .leading, spacing: DesignConstants.Spacing.relatedContent) {
      archiveSectionHeader(content)

      if let error = content.listError {
        archiveErrorView(error)
      } else {
        archiveEntryList(content)
      }
    }
    .padding(DesignConstants.Padding.card)
    .sectionBackground()
  }

  private func archiveSectionHeader(_ content: ArchiveContent) -> some View {
    VStack(alignment: .leading, spacing: DesignConstants.Spacing.sectionHeader) {
      HStack {
        Image(systemName: "doc.zipper")
          .foregroundStyle(AppColors.acHeaderInfo)
          .font(DesignConstants.Font.headline)
        Text(content.archiveName)
          .font(DesignConstants.Font.body)
          .lineLimit(1)
        Spacer()
        if content.listError == nil {
          Text(String(format: loc("%d files"), content.entries.count))
            .font(DesignConstants.Font.caption)
            .foregroundStyle(AppColors.acFileCount)
            .monospacedDigit()
        }
      }

      if content.listError == nil {
        HStack(spacing: DesignConstants.Spacing.relatedContent) {
          Text(content.format.displayName)
            .font(DesignConstants.Font.caption)
            .foregroundStyle(AppColors.acFormatBadge)
            .padding(.horizontal, DesignConstants.Padding.horizontalTight)
            .padding(.vertical, DesignConstants.Padding.verticalMinimum)
            .badgeBackground()

          Button(loc("Select All")) {
            selectedPaths[content.sourceURL] = Set(
              content.entries.filter { !$0.isDirectory }.map(\.path))
          }
          .inlineButton()

          Button(loc("Deselect All")) {
            selectedPaths[content.sourceURL] = []
          }
          .inlineButton()
        }
      }
    }
  }

  private func archiveErrorView(_ error: String) -> some View {
    HStack(spacing: DesignConstants.Spacing.relatedContent) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(AppColors.acErrorIcon)
        .font(DesignConstants.Font.subheadline)
      Text(error)
        .font(DesignConstants.Font.caption)
        .foregroundStyle(AppColors.acErrorText)
    }
    .padding(DesignConstants.Padding.error)
    .cardBackground(cornerRadius: 8)
  }

  private func archiveEntryList(_ content: ArchiveContent) -> some View {
    VStack(alignment: .leading, spacing: DesignConstants.Spacing.labelPair) {
      Divider()
        .padding(.vertical, DesignConstants.Padding.verticalCompact)

      ForEach(content.entries.filter { !$0.isDirectory }) { entry in
        ArchiveEntryRow(
          entry: entry,
          isSelected: toggleBinding(for: entry, archiveURL: content.sourceURL)
        )
      }

      if content.entries.filter({ !$0.isDirectory }).isEmpty {
        Text(loc("No files found in archive"))
          .font(DesignConstants.Font.body)
          .foregroundStyle(AppColors.acEmptyText)
          .padding(.vertical, DesignConstants.Padding.verticalDefault)
          .padding(.leading, DesignConstants.Padding.leadingTight)
      }
    }
  }

  private func toggleBinding(for entry: ArchiveEntry, archiveURL: URL) -> Binding<Bool> {
    Binding(
      get: { selectedPaths[archiveURL]?.contains(entry.path) ?? false },
      set: { newValue in
        if newValue {
          selectedPaths[archiveURL, default: []].insert(entry.path)
        } else {
          selectedPaths[archiveURL]?.remove(entry.path)
        }
      }
    )
  }

  private func initializeSelection() {
    for content in viewModel.archiveContents where content.listError == nil {
      selectedPaths[content.sourceURL] = Set(content.entries.filter { !$0.isDirectory }.map(\.path))
    }
  }

  private var actionButtons: some View {
    HStack(spacing: DesignConstants.Spacing.sectionGroup) {
      Button(loc("Back")) {
        viewModel.backToFiles()
      }
      .secondaryButton()
      .keyboardShortcut(.escape)

      Spacer()

      Button(loc("Extract All")) {
        viewModel.extractAll()
      }
      .secondaryButton()
      .keyboardShortcut("e", modifiers: [.command, .shift])

      Button(loc("Extract Selected")) {
        let filtered = selectedPaths.filter { !$0.value.isEmpty }
        viewModel.extractAll(selectedEntries: filtered.isEmpty ? nil : filtered)
      }
      .primaryButton()
      .keyboardShortcut("e")
      .disabled(selectedPaths.values.allSatisfy(\.isEmpty))
    }
  }
}

private struct ArchiveEntryRow: View {
  let entry: ArchiveEntry
  @Binding var isSelected: Bool

  var body: some View {
    Button {
      isSelected.toggle()
    } label: {
      HStack(spacing: DesignConstants.Spacing.relatedContent) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isSelected ? AppColors.acCheckIcon : AppColors.acDocIcon)
          .font(DesignConstants.Font.body)

        Text(entry.path)
          .font(DesignConstants.Font.body)
          .lineLimit(1)

        Spacer()

        if entry.size > 0 {
          Text(formattedSize(entry.size))
            .font(DesignConstants.Font.caption)
            .foregroundStyle(AppColors.acFileSize)
            .monospacedDigit()
            .fixedSize()
        }
      }
      .padding(.vertical, DesignConstants.Padding.verticalCompact)
      .padding(.horizontal, DesignConstants.Padding.horizontalExtraTight)
      .contentShape(Rectangle())
    }
    .buttonStyle(SelectableRowButtonStyle(isSelected: isSelected))
  }

  private func formattedSize(_ size: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
  }
}
