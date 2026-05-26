import SwiftUI

struct HelpView: View {
    @Environment(\.dismissWindow)
    private var dismissWindow

    var body: some View {
        TabView {
            usageTab
                .tabItem { Label("Usage", systemImage: "book") }

            formatsTab
                .tabItem { Label("Supported Formats", systemImage: "doc.zipper") }

            tipsTab
                .tabItem { Label("Tips", systemImage: "lightbulb") }
        }
        .padding(.top, 8)
        .frame(minWidth: 480, minHeight: 360)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismissWindow(id: "help") }
            }
        }
    }

    private var usageTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("How to extract archives") {
                    step("1", "Drop archives onto the main window, or click Select Files to browse.")
                    step("2", "If the archive is password-protected, enable the toggle and enter the password.")
                    step("3", "Choose whether to extract in place (files go directly into the source directory).")
                    step("4", "Click Extract All. Progress is shown during extraction.")
                    step("5", "When complete, click Reveal in Finder to locate the extracted files.")
                }

                section("Adding files") {
                    bullet("Drag and drop one or more archive files onto the drop zone.")
                    bullet("Click Select Files to use the system file picker.")
                    bullet("Supported formats are detected automatically by extension and magic bytes.")
                }

                section("Extraction behavior") {
                    bullet("By default, each archive extracts into a subfolder named after the archive (e.g., project.zip → project/).")
                    bullet("Enable Extract in place to extract directly into the source directory.")
                    bullet("In Settings, you can choose a custom default output directory.")
                    bullet("Enable Move archive to Trash to clean up the original after extraction.")
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .padding()
    }

    private var formatsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ArchiveFormat.allCases, id: \.self) { format in
                    HStack {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                        Text(format.displayName)
                            .font(.body)
                        Spacer()
                        Text(format.fileExtensions.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(magicDescription(for: format))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .padding()
    }

    private var tipsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("Keyboard shortcuts") {
                    shortcut("Cmd+O", "Open file picker")
                    shortcut("Cmd+E", "Extract all selected archives")
                    shortcut("Cmd+Shift+O", "Open Settings (output directory)")
                    shortcut("Cmd+?", "Open this help window")
                }

                section("Troubleshooting") {
                    bullet("If extraction fails, check that the archive is not corrupted.")
                    bullet("Password-protected ZIP archives require the correct password and use /usr/bin/unzip.")
                    bullet("7Z and RAR archives use /usr/bin/unar for extraction.")
                    bullet("For very large archives, extraction may take a few moments.")
                    bullet("If a format is not detected, try renaming the file to include a standard extension.")
                    bullet("For split archives (e.g., .part01.rar, .7z.001), only the first part is needed — additional parts are automatically detected.")
                }

                section("About Decompress") {
                    Text("Decompress is a native macOS archive extraction utility. It uses system tools (ditto, tar, gunzip, bunzip2, unxz, unar, unzip) to handle a wide range of archive formats without any external dependencies.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
        .padding()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(.tint))
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shortcut(_ key: String, _ description: String) -> some View {
        HStack {
            Text(key)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(description)
                .font(.subheadline)
            Spacer()
        }
    }

    private func magicDescription(for format: ArchiveFormat) -> String {
        format.magicBytes.isEmpty ? "no magic bytes" : "magic: \(format.magicBytes.map { $0.hexString }.joined(separator: ", "))"
    }
}

extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }
}
