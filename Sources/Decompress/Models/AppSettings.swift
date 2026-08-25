import Foundation

struct AppSettings: Codable, Sendable, Equatable {
  var autoExtractToSourceDir = true
  var deleteArchiveAfterExtraction = false
  var outputDirectoryURL: URL?

  private static let storageKey = "appSettings"

  init() {}

  static func load(defaults: UserDefaults = .standard) -> AppSettings {
    guard let data = defaults.data(forKey: storageKey) else { return AppSettings() }
    do {
      return try JSONDecoder().decode(AppSettings.self, from: data)
    } catch {
      return AppSettings()
    }
  }

  func save(defaults: UserDefaults = .standard) {
    guard let data = try? JSONEncoder().encode(self) else { return }
    defaults.set(data, forKey: Self.storageKey)
  }
}
