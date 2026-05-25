import SwiftUI

struct SettingsView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            formatsTab
                .tabItem { Label("Formats", systemImage: "doc.zipper") }
        }
        .frame(width: 480, height: 300)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Extract to source directory by default", isOn: Bindable(viewModel).autoExtractToSourceDir)
                    .help("When enabled, archives are extracted into the same folder as the archive source")

                Toggle("Move archive to Trash after extraction", isOn: Bindable(viewModel).deleteArchiveAfterExtraction)
                    .help("Archives will be moved to Trash after successful extraction")
            }

            Section {
                HStack(alignment: .firstTextBaseline) {
                    Text("Default output location")
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if viewModel.autoExtractToSourceDir {
                            Text("Same as source")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(viewModel.outputDirectoryURL?.path ?? "Not set")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        if !viewModel.autoExtractToSourceDir {
                            Button("Choose…") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.canCreateDirectories = true
                                panel.message = "Select default extraction directory"
                                panel.begin { response in
                                    if response == .OK {
                                        viewModel.outputDirectoryURL = panel.url
                                    }
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
            .disabled(viewModel.autoExtractToSourceDir)
        }
        .padding(20)
    }

    private var formatsTab: some View {
        SupportedFormatsList()
            .padding(20)
    }
}

private struct SupportedFormatsList: View {
    var body: some View {
        List(ArchiveFormat.allCases, id: \.self) { format in
            HStack {
                Text(format.displayName)
                    .font(.body)
                Spacer()
                Text(format.fileExtensions.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
