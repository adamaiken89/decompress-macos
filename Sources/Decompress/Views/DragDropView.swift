import SwiftUI
import UniformTypeIdentifiers

struct DragDropView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel
    @State private var isTargeted = false
    @State private var detectedFormats: [URL: ArchiveFormat] = [:]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            dropIcon
            instructions
            selectButton
            if !viewModel.selectedURLs.isEmpty {
                selectedFilesSection
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
    }

    private var instructions: some View {
        VStack(spacing: 4) {
            Text("Drop archives here")
                .font(.title3)
                .fontWeight(.medium)

            Text("ZIP, TAR, GZIP, BZIP2, XZ, 7Z, RAR")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var selectButton: some View {
        Button("Select Files") {
            viewModel.showFilePicker = true
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var selectedFilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Selected (\(viewModel.selectedURLs.count) files)")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.selectedURLs, id: \.self) { url in
                FileRow(url: url, format: detectedFormats[url])
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Clear") {
                viewModel.clearFiles()
            }
            .buttonStyle(.bordered)

            Button("Extract All") {
                viewModel.extractAll()
            }
            .buttonStyle(.borderedProminent)
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
                }
            }
        }
    }
}

private struct FileRow: View {
    let url: URL
    let format: ArchiveFormat?

    var body: some View {
        HStack {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
            Text(url.lastPathComponent)
                .font(.subheadline)
                .lineLimit(1)
            if let format {
                Text(format.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}
