import SwiftUI

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
