import Foundation

extension FileManager {
    func uniqueDirectoryURL(
        in parent: URL,
        preferredName: String
    ) -> URL {
        var url = parent.appendingPathComponent(preferredName)
        var counter = 1
        while fileExists(atPath: url.path) {
            url = parent.appendingPathComponent("\(preferredName) \(counter)")
            counter += 1
        }
        return url
    }

    func suggestedDestinationURL(for sourceURL: URL) -> URL {
        let sourceName = sourceURL
            .deletingPathExtension()
            .lastPathComponent
        let parent = sourceURL.deletingLastPathComponent()
        return uniqueDirectoryURL(in: parent, preferredName: sourceName)
    }
}
