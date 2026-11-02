import CoreGraphics

// MARK: - Thumbnail Grid Metrics
struct ThumbnailGridMetrics {
    let contentWidth: CGFloat
    let columnCount: Int
    let columnWidth: CGFloat
    let thumbnailSize: CGFloat

    init(panelWidth: CGFloat, preferredSize: CGFloat, horizontalPadding: CGFloat, columnSpacing: CGFloat) {
        contentWidth = max(1, panelWidth - horizontalPadding)
        let preferredColumnWidth = max(1, preferredSize) + 16
        columnCount = max(1, Int((contentWidth + columnSpacing) / (preferredColumnWidth + columnSpacing)))
        columnWidth = max(1, (contentWidth - CGFloat(columnCount - 1) * columnSpacing) / CGFloat(columnCount))
        thumbnailSize = min(max(1, preferredSize), max(1, columnWidth - 16))
    }
}
