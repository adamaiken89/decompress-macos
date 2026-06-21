import SwiftUI

enum DesignConstants {
  enum Spacing {
    static let zero: CGFloat = 0
    static let rowContent: CGFloat = 1
    static let labelPair: CGFloat = 2
    static let fileList: CGFloat = 4
    static let sectionHeader: CGFloat = 6
    static let relatedContent: CGFloat = 8
    static let groupBox: CGFloat = 10
    static let sectionGroup: CGFloat = 12
    static let progressContent: CGFloat = 16
    static let pageSection: CGFloat = 20
    static let pageWide: CGFloat = 24
  }

  enum Padding {
    static let border: CGFloat = 1
    static let extraCompact: CGFloat = 8
    static let error: CGFloat = 10
    static let card: CGFloat = 12
    static let section: CGFloat = 14
    static let group: CGFloat = 16
    static let settingsTab: CGFloat = 20
    static let progressCard: CGFloat = 24
    static let dropZone: CGFloat = 48

    static let horizontalExtraTight: CGFloat = 4
    static let horizontalTight: CGFloat = 6
    static let horizontalDefault: CGFloat = 8
    static let verticalMinimum: CGFloat = 2
    static let verticalCompact: CGFloat = 3
    static let verticalTight: CGFloat = 4
    static let verticalDefault: CGFloat = 6
    static let leadingTight: CGFloat = 4
    static let topTight: CGFloat = 8
  }

  enum FontSize {
    static let largeIcon: CGFloat = 80
    static let icon: CGFloat = 64
    static let statusIcon: CGFloat = 32
    static let smallIcon: CGFloat = 28
  }

  enum Layout {
    static let passwordCardWidth: CGFloat = 280
    static let progressBarWidth: CGFloat = 260
    static let messageMaxWidth: CGFloat = 300
    static let spinnerScale: CGFloat = 1.1
  }

  enum Font {
    static let title = SwiftUI.Font.title
    static let title2 = SwiftUI.Font.title2
    static let title3 = SwiftUI.Font.title3
    static let headline = SwiftUI.Font.headline
    static let body = SwiftUI.Font.body
    static let subheadline = SwiftUI.Font.subheadline
    static let caption = SwiftUI.Font.caption
  }
}
