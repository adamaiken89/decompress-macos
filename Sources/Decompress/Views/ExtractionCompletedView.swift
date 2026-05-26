import SwiftUI

struct ExtractionCompletedView: View {
    let result: ExtractionResult

    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Extraction Complete")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                resultRow("Format", result.format.displayName, "doc.zipper")
                resultRow("Files extracted", "\(result.fileCount)", "doc.on.doc")
                resultRow("Total size", result.formattedSize, "externaldrive")
                if let duration = result.formattedDuration {
                    resultRow("Duration", duration, "clock")
                }
                resultRow("Location", result.destinationURL.path, "folder")
            }
            .font(.subheadline)

            HStack(spacing: 12) {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(
                        result.destinationURL.path,
                        inFileViewerRootedAtPath: result.destinationURL
                            .deletingLastPathComponent().path
                    )
                }
                .keyboardShortcut("r")

                Button("Open Folder") {
                    NSWorkspace.shared.open(result.destinationURL)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.destinationURL.path, forType: .string)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Extract Another") {
                    viewModel.reset()
                }
                .keyboardShortcut(.escape)
                .keyboardShortcut("n")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Extraction completed")
    }

    private func resultRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
