import SwiftUI

struct SettingsView: View {
    @Environment(DecompressViewModel.self)
    private var viewModel

    var body: some View {
        TabView {
            Form {
                Toggle("Extract to source directory", isOn: Bindable(viewModel).autoExtractToSourceDir)
                    .help("When enabled, archives are extracted into the same folder as the archive")

                Toggle("Move archive to Trash after extraction", isOn: Bindable(viewModel).deleteArchiveAfterExtraction)
                    .help("Archives will be moved to Trash after successful extraction")

                Divider()

                HStack {
                    Text("Default output location")
                    Spacer()
                    Text(viewModel.outputDirectoryURL?.path ?? "Same as source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !viewModel.autoExtractToSourceDir {
                        Button("Choose...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.canCreateDirectories = true
                            panel.begin { response in
                                if response == .OK {
                                    viewModel.outputDirectoryURL = panel.url
                                }
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .padding()

            Form {
                SupportedFormatsList()
            }
            .tabItem {
                Label("Formats", systemImage: "doc.zipper")
            }
            .padding()
        }
        .frame(width: 450, height: 250)
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
