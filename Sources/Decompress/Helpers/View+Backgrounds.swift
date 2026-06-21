import SwiftUI

struct SelectableRowButtonStyle: ButtonStyle {
  let isSelected: Bool
  @State private var isHovered = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background {
        RoundedRectangle(cornerRadius: 4)
          .fill(backgroundColor(isPressed: configuration.isPressed))
      }
      .opacity(configuration.isPressed ? 0.85 : 1)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
      .onHover { hovering in
        withAnimation(.easeOut(duration: 0.15)) {
          isHovered = hovering
        }
      }
  }

  private func backgroundColor(isPressed: Bool) -> Color {
    if isPressed { return AppColors.frHoverBackground }
    if isSelected { return AppColors.acSelectedBackground }
    if isHovered { return AppColors.frHoverBackground }
    return AppColors.bgRow
  }
}

extension View {
  func cardBackground(cornerRadius: CGFloat = 10) -> some View {
    self.background(
      AppColors.bgCard,
      in: RoundedRectangle(cornerRadius: cornerRadius)
    )
  }

  func sectionBackground(cornerRadius: CGFloat = 12) -> some View {
    self.background(
      AppColors.bgSection,
      in: RoundedRectangle(cornerRadius: cornerRadius)
    )
  }

  func rowBackground(cornerRadius: CGFloat = 6) -> some View {
    self.background(
      AppColors.bgRow,
      in: RoundedRectangle(cornerRadius: cornerRadius)
    )
  }

  func badgeBackground() -> some View {
    self.background(
      AppColors.bgBadge,
      in: Capsule()
    )
  }
}
