// ResourceMonitorToolbarItem.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Compact live toolbar graphs for application memory and thread usage.

import AppKit
import Observation
import SwiftUI

// MARK: - Resource Monitor Model
@MainActor
@Observable
private final class ResourceMonitorModel {
    static let shared = ResourceMonitorModel()
    private(set) var memoryHistory: [Double] = []
    private(set) var threadHistory: [Double] = []
    private(set) var memoryLabel = "— MB"
    private(set) var threadLabel = "—"
    private var timer: Timer?

    private init() {
        sample()
        let timer = Timer(timeInterval: 2, target: self, selector: #selector(sample), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Sample Process Metrics
    @objc private func sample() {
        let snapshot = MemoryDiagnostics.capture()
        memoryLabel = MemoryDiagnostics.wholeMemoryLabel(bytes: snapshot.footprintBytes)
        threadLabel = snapshot.threadCount > 0 ? "\(snapshot.threadCount)" : "—"
        withAnimation(.easeInOut(duration: 0.35)) {
            memoryHistory = Self.appending(Double(snapshot.footprintBytes) / 1_048_576, to: memoryHistory)
            threadHistory = Self.appending(Double(snapshot.threadCount), to: threadHistory)
        }
    }

    // MARK: - Rolling History
    private static func appending(_ value: Double, to history: [Double]) -> [Double] {
        Array((history + [value]).suffix(24))
    }
}

// MARK: - Resource Monitor Toolbar Item
struct ResourceMonitorToolbarItem: View {
    let showMemory: Bool
    let showThreads: Bool
    @State private var model = ResourceMonitorModel.shared

    // MARK: - Body
    var body: some View {
        HStack(spacing: 7) {
            if showMemory {
                metric(title: "RAM", value: model.memoryLabel, history: model.memoryHistory, color: #colorLiteral(red: 0.176, green: 0.686, blue: 0.435, alpha: 1))
            }
            if showMemory && showThreads { Divider().frame(height: 26) }
            if showThreads {
                metric(title: "THR", value: model.threadLabel, history: model.threadHistory, color: #colorLiteral(red: 0.278, green: 0.518, blue: 0.941, alpha: 1))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background { monitorSurface }
        .fixedSize()
        .help(helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var helpText: String {
        if showMemory && showThreads { return "MiMiNavigator physical memory and live thread count" }
        return showMemory ? "MiMiNavigator physical memory" : "MiMiNavigator live thread count"
    }

    private var accessibilityText: String {
        if showMemory && showThreads { return "Memory \(model.memoryLabel), threads \(model.threadLabel)" }
        return showMemory ? "Memory \(model.memoryLabel)" : "Threads \(model.threadLabel)"
    }

    // MARK: - Metric
    private func metric(title: String, value: String, history: [Double], color: NSColor) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(minWidth: title == "RAM" ? 42 : 20, alignment: .trailing)
            }
            ResourceSparkline(values: history, color: Color(nsColor: color))
                .frame(width: 34, height: 24)
        }
    }

    // MARK: - Surface
    private var monitorSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.blue.opacity(0.08))
                .offset(y: 1.5)
                .shadow(color: Color.black.opacity(0.12), radius: 3, y: 2)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.78), Color.white.opacity(0.48), Color.blue.opacity(0.045)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white, Color.blue.opacity(0.20), Color.blue.opacity(0.42)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .overlay(alignment: .top) {
                    Capsule().fill(Color.white.opacity(0.72)).frame(height: 0.8).padding(.horizontal, 8).padding(.top, 1.5)
                }
        }
    }
}

// MARK: - Resource Sparkline
/// Adapted from Hop's MIT-licensed compact Sparkline view by Anton Shakirov.
private struct ResourceSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let low = values.min() ?? 0
            let high = values.max() ?? 1
            let span = max(high - low, 0.0001)
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height * (1 - CGFloat((value - low) / span)) * 0.8 + size.height * 0.1
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color.opacity(0.92)), style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round))
        }
    }
}
