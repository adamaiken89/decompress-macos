import Foundation

struct ExtractionQueue: Sendable, Equatable {
  private(set) var pending: [[URL]] = []

  var count: Int { pending.count }
  var isEmpty: Bool { pending.isEmpty }

  mutating func enqueue(_ urls: [URL]) {
    pending.append(urls)
  }

  mutating func popNext() -> [URL]? {
    pending.isEmpty ? nil : pending.removeFirst()
  }

  mutating func removeAll() {
    pending.removeAll()
  }
}
