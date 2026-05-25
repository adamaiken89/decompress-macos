import SwiftUI

extension View {
  func primaryButton() -> some View {
    self.buttonStyle(.borderedProminent)
      .controlSize(.large)
      .buttonBorderShape(.roundedRectangle(radius: 8))
  }

  func secondaryButton() -> some View {
    self.buttonStyle(.bordered)
      .controlSize(.regular)
      .buttonBorderShape(.roundedRectangle(radius: 8))
  }

  func inlineButton() -> some View {
    self.buttonStyle(.plain)
      .font(.subheadline)
      .foregroundStyle(AppColors.btnInlineLabel)
  }
}
