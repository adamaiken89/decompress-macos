import SwiftUI

struct FileRowView: View {
  let url: URL
  let format: ArchiveFormat?
  let onRemove: () -> Void
  let onDoubleClick: () -> Void
  let onPreview: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: DesignConstants.Spacing.groupBox) {
      Image(systemName: formatIcon)
        .font(DesignConstants.Font.body)
        .foregroundStyle(AppColors.frIcon)
        .frame(width: 18)
        .accessibilityHidden(true)

      Text(url.lastPathComponent)
        .font(DesignConstants.Font.body)
        .fontWeight(.medium)
        .lineLimit(1)
        .help(url.path)

      if let format {
        Text(format.displayName)
          .font(DesignConstants.Font.caption)
          .foregroundStyle(AppColors.frFormatLabel)
          .padding(.horizontal, DesignConstants.Padding.horizontalTight)
          .padding(.vertical, DesignConstants.Padding.verticalMinimum)
          .badgeBackground()
      }

      Spacer()

      Button {
        onRemove()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(DesignConstants.Font.body)
          .symbolRenderingMode(.hierarchical)
      }
      .buttonStyle(.plain)
      .foregroundStyle(AppColors.frRemoveButton)
      .help(String(format: loc("Remove %@"), url.lastPathComponent))
      .accessibilityLabel(String(format: loc("Remove %@"), url.lastPathComponent))
    }
    .padding(.vertical, DesignConstants.Padding.verticalTight)
    .padding(.horizontal, DesignConstants.Padding.horizontalTight)
    .onHover { hovering in
      withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
        isHovered = hovering
      }
    }
    .background(
      isHovered ? AppColors.frHoverBackground : .clear, in: RoundedRectangle(cornerRadius: 6)
    )
    .onTapGesture {
      onPreview()
    }
    .highPriorityGesture(
      TapGesture(count: 2)
        .onEnded { onDoubleClick() }
    )
    .contextMenu {
      Button(loc("Browse")) {
        onPreview()
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      String(
        format: loc("%@, %@"), url.lastPathComponent, format?.displayName ?? loc("unknown format")))
  }

  private var formatIcon: String {
    switch format {
    case .zip: "doc.zipper"
    case .tar, .tarGz, .tarBz2, .tarXz: "archivebox"
    case .gzip: "doc.compress"
    case .bzip2: "doc.compress"
    case .xz: "doc.compress"
    case .sevenZip: "archivebox"
    case .rar: "doc.zipper"
    case .split: "doc.badge.gearshape"
    case nil: "doc"
    }
  }
}
