import SwiftUI

enum AppColors {

  // MARK: - Drop Zone
  static let dzIconDefault = Color.secondary
  static let dzIconActive = Color.accentColor
  static let dzSubtitle = Color.secondary
  static let dzHint = Color.secondary
  static let dzBorderDefault = Color(nsColor: .separatorColor)
  static let dzBorderActive = Color.accentColor
  static let dzShadowDefault = Color(nsColor: .separatorColor)
  static let dzShadowActive = Color.secondary

  // MARK: - File Row
  static let frIcon = Color.secondary
  static let frFormatLabel = Color.secondary
  static let frRemoveButton = Color.secondary
  static let frHoverBackground = Color(nsColor: .selectedControlColor)

  // MARK: - Password Prompt
  static let ppKeyIcon = Color.accentColor

  // MARK: - Button Styles
  static let btnInlineLabel = Color.accentColor

  // MARK: - Extraction Progress
  static let epProgressTint = Color.accentColor
  static let epFileName = Color.secondary
  static let epDetail = Color.secondary

  // MARK: - Extraction Completed / Failed
  static let ecSuccessIcon = Color.green
  static let ecFailureIcon = Color.red
  static let ecWarningIcon = Color.yellow
  static let ecSectionTitle = Color.secondary
  static let ecSectionFailedTitle = Color.red
  static let ecSummaryText = Color.secondary
  static let ecFileDetail = Color.secondary
  static let efIcon = Color.red
  static let efMessage = Color.secondary

  // MARK: - Archive Content
  static let acHeaderInfo = Color.secondary
  static let acFileCount = Color.secondary
  static let acFormatBadge = Color.secondary
  static let acErrorIcon = Color.yellow
  static let acErrorText = Color.secondary
  static let acEmptyText = Color.secondary
  static let acDocIcon = Color.secondary
  static let acFileSize = Color.secondary
  static let acSelectedBackground = Color.accentColor.opacity(0.15)
  static let acCheckIcon = Color.accentColor

  // MARK: - Help View
  static let hvFormatIcon = Color.secondary
  static let hvFormatExtension = Color.secondary
  static let hvFormatMagic = Color(nsColor: .tertiaryLabelColor)
  static let hvBullet = Color.secondary
  static let hvDescription = Color.secondary
  static let hvVersion = Color.secondary

  // MARK: - Settings
  static let stFolderIcon = Color.secondary
  static let stFolderLabel = Color.secondary
  static let stHint = Color.secondary
  static let stFormatIcon = Color.secondary
  static let stFormatExtension = Color.secondary

  // MARK: - Backgrounds
  static let bgCard = Color(nsColor: .windowBackgroundColor)
  static let bgSection = Color(nsColor: .windowBackgroundColor)
  static let bgRow = Color(nsColor: .controlBackgroundColor)
  static let bgBadge = Color(nsColor: .controlBackgroundColor)
}
