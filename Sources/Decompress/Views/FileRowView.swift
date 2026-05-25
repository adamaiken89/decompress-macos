import SwiftUI

struct FileRowView: View {
    let url: URL
    let format: ArchiveFormat?
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(url.lastPathComponent)
                .font(.subheadline)
                .lineLimit(1)
                .help(url.path)

            if let format {
                Text(format.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove \(url.lastPathComponent)")
            .accessibilityLabel("Remove \(url.lastPathComponent)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(url.lastPathComponent), \(format?.displayName ?? "unknown format")")
    }
}
