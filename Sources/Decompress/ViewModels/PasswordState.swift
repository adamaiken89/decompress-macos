import Foundation

struct PasswordState: Sendable, Equatable {
  var isProtected = false
  var value = ""
  var error: String?

  mutating func clear() {
    self = PasswordState()
  }

  func effectivePassword() -> String? {
    isProtected && !value.isEmpty ? value : nil
  }
}
