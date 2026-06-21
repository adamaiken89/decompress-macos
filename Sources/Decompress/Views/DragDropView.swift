import SwiftUI
import UniformTypeIdentifiers

struct DragDropView: View {
  @Environment(DecompressViewModel.self)
  private var viewModel
  @State private var isTargeted = false
  @State private var detectedFormats: [URL: ArchiveFormat] = [:]

  var body: some View {
    VStack(spacing: DesignConstants.Spacing.zero) {
      if viewModel.selectedURLs.isEmpty {
        dropZone
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        compactDropBar
          .padding(.horizontal, DesignConstants.Padding.group)
          .padding(.vertical, DesignConstants.Padding.card)

        selectedFilesSection
          .frame(maxHeight: .infinity)

        bottomControls
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
      handleDrop(providers: providers)
      return true
    }
    .fileImporter(
      isPresented: Bindable(viewModel).showFilePicker,
      allowedContentTypes: allowedTypes,
      allowsMultipleSelection: true,
      onCompletion: handleFilePicker
    )
  }

  private var dropZone: some View {
    VStack(spacing: DesignConstants.Spacing.pageWide) {
      Image(systemName: "doc.zipper")
        .font(.system(size: DesignConstants.FontSize.largeIcon))
        .foregroundStyle(isTargeted ? AppColors.dzIconActive : AppColors.dzIconDefault)
        .symbolEffect(.bounce, value: isTargeted)
        .accessibilityHidden(true)

      VStack(spacing: DesignConstants.Spacing.relatedContent) {
        Text(loc("Drop archives here"))
          .font(DesignConstants.Font.title)
          .fontWeight(.medium)

        Text(loc("ZIP · TAR · GZIP · BZIP2 · XZ · 7Z · RAR"))
          .font(DesignConstants.Font.body)
          .foregroundStyle(AppColors.dzSubtitle)

        Text(loc("Click to select or drag files"))
          .font(DesignConstants.Font.subheadline)
          .foregroundStyle(AppColors.dzHint)
      }

      Text(loc("For split archives, only the first part is needed"))
        .font(DesignConstants.Font.subheadline)
        .foregroundStyle(AppColors.dzHint)
    }
    .padding(DesignConstants.Padding.dropZone)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(AppColors.bgCard)
        .overlay(dropBorder)
        .shadow(
          color: isTargeted ? AppColors.dzShadowActive : AppColors.dzShadowDefault,
          radius: isTargeted ? 20 : 8,
          y: isTargeted ? 8 : 2)
    )
    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isTargeted)
    .accessibilityLabel(
      loc("Drop archives here. Supported formats: ZIP, TAR, GZIP, BZIP2, XZ, 7Z, RAR")
    )
    .accessibilityAddTraits(.isButton)
    .onTapGesture {
      viewModel.showFilePicker = true
    }
    .onContinuousHover { phase in
      switch phase {
      case .active: NSCursor.pointingHand.set()
      case .ended: NSCursor.arrow.set()
      }
    }
  }

  private var dropBorder: some View {
    RoundedRectangle(cornerRadius: 16)
      .stroke(
        isTargeted
          ? AnyShapeStyle(AppColors.dzBorderActive)
          : AnyShapeStyle(AppColors.dzBorderDefault),
        style: StrokeStyle(lineWidth: isTargeted ? 3 : 1.5, dash: [8])
      )
      .padding(DesignConstants.Padding.border)
  }

  private var compactDropBar: some View {
    HStack(spacing: DesignConstants.Spacing.sectionGroup) {
      Image(systemName: "doc.badge.plus")
        .foregroundStyle(AppColors.dzSubtitle)
        .accessibilityHidden(true)

      Text(loc("Drop more archives or click to add"))
        .font(DesignConstants.Font.subheadline)
        .foregroundStyle(AppColors.dzSubtitle)
        .lineLimit(1)

      Spacer()

      Button(loc("Select Files")) {
        viewModel.showFilePicker = true
      }
      .inlineButton()
    }
    .padding(DesignConstants.Padding.card)
    .background(AppColors.bgCard, in: RoundedRectangle(cornerRadius: 10))
    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
      handleDrop(providers: providers)
      return true
    }
  }

  private var selectedFilesSection: some View {
    VStack(alignment: .leading, spacing: DesignConstants.Spacing.relatedContent) {
      HStack {
        Text(String(format: loc("Selected %d files"), viewModel.selectedURLs.count))
          .font(DesignConstants.Font.body)
          .foregroundStyle(AppColors.dzSubtitle)
          .monospacedDigit()

        Spacer()

        Button(loc("Deselect All")) {
          viewModel.clearFiles()
        }
        .inlineButton()
      }
      .padding(.horizontal, DesignConstants.Padding.group)
      .padding(.bottom, DesignConstants.Padding.verticalMinimum)

      ScrollView {
        LazyVStack(spacing: DesignConstants.Spacing.fileList) {
          ForEach(Array(viewModel.selectedURLs.enumerated()), id: \.element) { index, url in
            FileRowView(
              url: url,
              format: detectedFormats[url],
              onRemove: { viewModel.removeFile(at: index) },
              onDoubleClick: { viewModel.extractAll() },
              onPreview: { viewModel.previewArchives() }
            )
          }
        }
        .padding(.horizontal, DesignConstants.Padding.card)
      }
    }
  }

  private var bottomControls: some View {
    VStack(spacing: DesignConstants.Spacing.sectionGroup) {
      if viewModel.isPasswordProtected {
        PasswordPromptView()
      }

      HStack(spacing: DesignConstants.Spacing.pageSection) {
        Toggle(loc("Extract in place"), isOn: Bindable(viewModel).extractInPlace)
          .help(loc("Extract files directly into the source directory instead of a subfolder"))
          .font(DesignConstants.Font.body)

        Spacer()

        HStack(spacing: DesignConstants.Spacing.sectionGroup) {
          Button(loc("Clear")) {
            viewModel.clearFiles()
          }
          .secondaryButton()
          .keyboardShortcut(.escape)
          .disabled(viewModel.selectedURLs.isEmpty)

          Button(loc("Browse")) {
            viewModel.previewArchives()
          }
          .secondaryButton()
          .keyboardShortcut("p")
          .disabled(viewModel.selectedURLs.isEmpty)
          .help(loc("Browse archive contents before extraction"))

          Button(loc("Extract All")) {
            viewModel.extractAll()
          }
          .primaryButton()
          .keyboardShortcut("e")
          .disabled(viewModel.selectedURLs.isEmpty)
          .help(loc("Begin extraction of all selected archives"))
        }
      }
    }
    .padding(DesignConstants.Padding.group)
    .sectionBackground()
  }

  private var allowedTypes: [UTType] {
    [
      .archive, .zip, .gzip, .bz2,
      UTType(filenameExtension: "xz") ?? .data,
      UTType(filenameExtension: "tar") ?? .data,
      UTType(filenameExtension: "7z") ?? .data,
      UTType(filenameExtension: "rar") ?? .data,
      UTType(filenameExtension: "tbz") ?? .data,
      UTType(filenameExtension: "tbz2") ?? .data,
      UTType(filenameExtension: "tgz") ?? .data,
      UTType(filenameExtension: "txz") ?? .data,
    ]
  }

  private func handleFilePicker(_ result: Result<[URL], any Error>) {
    guard case .success(let urls) = result else { return }
    detectedFormats = [:]
    for url in urls {
      detectedFormats[url] = viewModel.detectFormat(for: url)
    }
    viewModel.addFiles(urls)
    viewModel.checkForEncryptedArchives(urls)
  }

  private func handleDrop(providers: [NSItemProvider]) {
    for provider in providers {
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
        guard let data = item as? Data,
          let url = URL(dataRepresentation: data, relativeTo: nil)
        else { return }
        Task { @MainActor in
          detectedFormats[url] = viewModel.detectFormat(for: url)
          viewModel.addFiles([url])
          viewModel.checkForEncryptedArchives([url])
        }
      }
    }
  }
}
