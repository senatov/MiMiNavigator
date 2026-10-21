// ResourceMonitorCharts.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact engineering-style charts for live application resources.

import SwiftUI

// MARK: - Resource Chart Scale
struct ResourceChartScale {
    static let capacity = 24

    // MARK: - Memory Ceiling
    static func memoryCeiling(_ values: [MemoryGraphSample]) -> Double {
        let peak = values.map(\.footprint).max() ?? 0
        return max(32, ceil(peak * 1.15 / 16) * 16)
    }

    // MARK: - Thread Bounds
    static func threadBounds(_ values: [Double]) -> ClosedRange<Double> {
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        return max(0, floor(low - 3))...max(6, ceil(high + 3))
    }

    // MARK: - Plot Point
    static func point(index: Int, count: Int, value: Double, bounds: ClosedRange<Double>, size: CGSize) -> CGPoint {
        let width = max(size.width - 6, 1)
        let height = max(size.height - 6, 1)
        let x = 3 + width * CGFloat(capacity - count + index) / CGFloat(capacity - 1)
        let fraction = min(max((value - bounds.lowerBound) / max(bounds.upperBound - bounds.lowerBound, 1), 0), 1)
        return CGPoint(x: x, y: 3 + height * CGFloat(1 - fraction))
    }
}

// MARK: - Resource Chart Drawing
private enum ResourceChartDrawing {
    static let footprint = Color(#colorLiteral(red: 0.10, green: 0.52, blue: 0.78, alpha: 1))
    static let compressed = Color(#colorLiteral(red: 0.85, green: 0.55, blue: 0.16, alpha: 1))
    static let threads = Color(#colorLiteral(red: 0.30, green: 0.46, blue: 0.75, alpha: 1))

    // MARK: - Grid
    static func grid(_ context: GraphicsContext, size: CGSize) {
        var path = Path()
        for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
            let y = 3 + (size.height - 6) * fraction
            path.move(to: CGPoint(x: 3, y: y))
            path.addLine(to: CGPoint(x: size.width - 3, y: y))
        }
        for fraction in [CGFloat(0.25), CGFloat(0.5), CGFloat(0.75)] {
            let x = 3 + (size.width - 6) * fraction
            path.move(to: CGPoint(x: x, y: 3))
            path.addLine(to: CGPoint(x: x, y: size.height - 3))
        }
        context.stroke(path, with: .color(Color.primary.opacity(0.10)), lineWidth: 0.5)
    }

    // MARK: - Line
    static func line(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    // MARK: - Area
    static func area(upper: [CGPoint], lower: [CGPoint]) -> Path {
        var path = line(upper)
        for point in lower.reversed() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    // MARK: - Current Marker
    static func marker(_ context: GraphicsContext, point: CGPoint, color: Color) {
        let circle = Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4))
        context.fill(circle, with: .color(color))
        context.stroke(circle, with: .color(Color(nsColor: .windowBackgroundColor)), lineWidth: 0.75)
    }
}

// MARK: - Resource Chart Frame
private struct ResourceChartFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content

    // MARK: - Body
    var body: some View {
        content()
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.13), lineWidth: 0.5) }
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Memory Resource Chart
struct MemoryResourceChart: View {
    let samples: [MemoryGraphSample]

    // MARK: - Body
    var body: some View {
        ResourceChartFrame {
            Canvas { context, size in
                ResourceChartDrawing.grid(context, size: size)
                guard !samples.isEmpty else { return }
                let bounds = 0...ResourceChartScale.memoryCeiling(samples)
                let total = samples.enumerated().map { ResourceChartScale.point(index: $0.offset, count: samples.count, value: $0.element.footprint, bounds: bounds, size: size) }
                let active = samples.enumerated().map { ResourceChartScale.point(index: $0.offset, count: samples.count, value: $0.element.uncompressed, bounds: bounds, size: size) }
                let baseline = total.map { CGPoint(x: $0.x, y: size.height - 3) }
                if samples.count > 1 {
                    context.fill(ResourceChartDrawing.area(upper: total, lower: baseline), with: .color(ResourceChartDrawing.footprint.opacity(0.12)))
                    if samples.contains(where: { $0.compressed > 0 }) {
                        context.fill(ResourceChartDrawing.area(upper: total, lower: active), with: .color(ResourceChartDrawing.compressed.opacity(0.34)))
                        context.stroke(ResourceChartDrawing.line(active), with: .color(ResourceChartDrawing.compressed), lineWidth: 0.7)
                    }
                    context.stroke(ResourceChartDrawing.line(total), with: .color(ResourceChartDrawing.footprint), style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
                }
                if let last = total.last { ResourceChartDrawing.marker(context, point: last, color: ResourceChartDrawing.footprint) }
            }
        }
    }
}

// MARK: - Thread Resource Chart
struct ThreadResourceChart: View {
    let values: [Double]

    // MARK: - Body
    var body: some View {
        ResourceChartFrame {
            Canvas { context, size in
                ResourceChartDrawing.grid(context, size: size)
                guard !values.isEmpty else { return }
                let bounds = ResourceChartScale.threadBounds(values)
                let points = values.enumerated().map { ResourceChartScale.point(index: $0.offset, count: values.count, value: $0.element, bounds: bounds, size: size) }
                if values.count > 1 {
                    let baseline = points.map { CGPoint(x: $0.x, y: size.height - 3) }
                    context.fill(ResourceChartDrawing.area(upper: points, lower: baseline), with: .color(ResourceChartDrawing.threads.opacity(0.10)))
                    context.stroke(ResourceChartDrawing.line(points), with: .color(ResourceChartDrawing.threads), style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
                }
                if let last = points.last { ResourceChartDrawing.marker(context, point: last, color: ResourceChartDrawing.threads) }
            }
        }
    }
}
