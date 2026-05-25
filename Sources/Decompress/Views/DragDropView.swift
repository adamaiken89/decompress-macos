import SwiftUI
import UniformTypeIdentifiers

struct DragDropView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel
    @State private var isTargeted = false
    @State private var detectedFormats: [URL: ArchiveFormat] = [:]

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            dropIcon
            instructions
            selectButton
            passwordPrompt

            if !viewModel.selectedURLs.isEmpty {
                selectedFilesSection
                extractionOptions
                actionButtons
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dropZoneBackground)
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

    private var dropIcon: some View {
        Image(systemName: "doc.zipper")
            .font(.system(size: 64))
            .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            .accessibilityHidden(true)
    }

    private var instructions: some View {
        VStack(spacing: 4) {
            Text("Drop archives here")
                .font(.title3)
                .fontWeight(.medium)

            Text("ZIP, TAR, GZIP, BZIP2, XZ, 7Z, RAR")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Drag files onto this window  ·  Select Files to browse")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityLabel("Drop archives here. Supported formats: ZIP, TAR, GZIP, BZIP2, XZ, 7Z, RAR")
    }

    private var selectButton: some View {
        Button("Select Files") {
            viewModel.showFilePicker = true
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut("o")
        .accessibilityHint("Opens a file picker to choose archive files")
    }

    private var passwordPrompt: some View {
        PasswordPromptView()
            .frame(maxWidth: 320)
    }

    private var selectedFilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Selected (\(viewModel.selectedURLs.count) files)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(viewModel.selectedURLs.enumerated()), id: \.element) { index, url in
                        FileRowView(
                            url: url,
                            format: detectedFormats[url],
                            onRemove: { viewModel.removeFile(at: index) }
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var extractionOptions: some View {
        HStack(spacing: 16) {
            Toggle("Extract in place", isOn: Bindable(viewModel).extractInPlace)
                .help("Extract files directly into the source directory instead of a subfolder")
        }
        .font(.caption)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Clear") {
                viewModel.clearFiles()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape)
            .disabled(viewModel.selectedURLs.isEmpty)

            Button("Extract All") {
                viewModel.extractAll()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("e")
            .disabled(viewModel.selectedURLs.isEmpty)
            .help("Begin extraction of all selected archives")
        }
    }

    private var dropZoneBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                style: StrokeStyle(lineWidth: isTargeted ? 3 : 2, dash: [8])
            )
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
