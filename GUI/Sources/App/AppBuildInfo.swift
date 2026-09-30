//
//  AppBuildInfo.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 13.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//  Description: Build info toolbar item and version string helpers.
//               Extracted from MiMiNavigatorApp.swift.

import SwiftUI

// MARK: - AppBuildInfo
/// Provides the build-info toolbar badge and version Text helpers.
/// Used by MiMiNavigatorApp to avoid polluting the @main App struct.
enum AppBuildInfo {

    // MARK: - toolBarItem
    /// ToolbarItem with TEST BUILD badge and optional resource graphs.
    @MainActor
    static func toolBarItem() -> ToolbarItem<(), some View> {
        ToolbarItem(placement: .status) {
            BuildInfoToolbarCluster(version: versionString())
        }
    }

    // MARK: - versionText
    /// Version Text read from curr_version.asc bundle resource, falls back to plist keys.
    static func versionText() -> Text {
        Text(versionString())
    }

    // MARK: - Version String

    static func versionString() -> String {
        if let url = Bundle.main.url(forResource: "curr_version", withExtension: "asc"),
           let raw = try? String(contentsOf: url, encoding: .utf8)
        {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (s?, b?): return "v\(s) (\(b))"
        case let (s?, nil): return "v\(s)"
        case let (nil, b?): return "build \(b)"
        default:
            log.error("failed to load version")
            return "MiMi Navigator — cannot determine version"
        }
    }
}

// MARK: - Build Info Toolbar Cluster
private struct BuildInfoToolbarCluster: View {
    let version: String
    @State private var prefs = UserPreferences.shared

    private var showMemory: Bool { prefs.snapshot.toolbarShowMemoryGraph ?? true }
    private var showThreads: Bool { prefs.snapshot.toolbarShowThreadsGraph ?? true }
    private var memoryInterval: TimeInterval { prefs.snapshot.toolbarMemoryGraphInterval ?? 5 }
    private var threadsInterval: TimeInterval { prefs.snapshot.toolbarThreadsGraphInterval ?? 10 }

    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            DevBuildBadge(version: version)
            if showMemory || showThreads {
                ResourceMonitorToolbarItem(
                    showMemory: showMemory,
                    showThreads: showThreads,
                    memoryInterval: memoryInterval,
                    threadsInterval: threadsInterval
                )
                    .offset(y: 6)
            }
        }
    }
}

// MARK: - DevBuildBadge

private struct DevBuildBadge: View {
    let version: String
    @State private var center = InAppNoticeCenter.shared
    @State private var isRivetPulsing = false
    @State private var isRivetHovered = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: -9) {
            badgeLabel
            GlossyNoticeRivet(color: center.historyRivetTint, isPulsing: isRivetPulsing, isHovered: isRivetHovered)
                .frame(width: 20, height: 20)
                .scaleEffect(isRivetPulsing ? 1.16 : isRivetHovered ? 1.10 : 1)
                .frame(width: 21, height: 21)
                .background {
                    RivetPointerMonitor(onHover: { isRivetHovered = $0 }, onClick: toggleHistory)
                }
                .animation(.easeOut(duration: 0.16), value: isRivetHovered)
                .zIndex(10)
                .help(center.isHistoryVisible ? "Hide recent messages" : "Show recent messages")
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(center.isHistoryVisible ? "Hide recent messages" : "Show recent messages")
                .accessibilityAction { toggleHistory() }
                .task(id: center.historyRivetPulse) {
                    guard center.historyRivetPulse > 0 else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.58)) { isRivetPulsing = true }
                    try? await Task.sleep(for: .milliseconds(700))
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { isRivetPulsing = false }
                }
        }
        .frame(height: 46, alignment: .center)
        .offset(y: 8)
    }

    // MARK: - Toggle History

    private func toggleHistory() {
        center.toggleHistory()
        log.info("[NoticeHistory] rivet clicked visible=\(center.isHistoryVisible)")
    }

    private var badgeLabel: some View {
        HStack(spacing: 8) {
            DevBuildCatMedallion()
            VStack(alignment: .leading, spacing: 1) {
                Text("TEST BUILD")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .tracking(0.5)
                    .foregroundStyle(Color.primary.opacity(0.90))
                Text(version)
                    .font(.system(size: 9, weight: .regular, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background { TopToolbarSurface() }
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .help("Current test build version")
    }
}

// MARK: - Rivet Pointer Monitor
private struct RivetPointerMonitor: NSViewRepresentable {
    let onHover: (Bool) -> Void
    let onClick: () -> Void

    func makeNSView(context: Context) -> RivetPointerView {
        let view = RivetPointerView()
        view.onHover = onHover
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: RivetPointerView, context: Context) {
        view.onHover = onHover
        view.onClick = onClick
    }

    static func dismantleNSView(_ view: RivetPointerView, coordinator: ()) {
        view.stopMonitoring()
    }
}

// MARK: - Rivet Pointer View
private final class RivetPointerView: NSView {
    var onHover: ((Bool) -> Void)?
    var onClick: (() -> Void)?
    private var eventMonitor: Any?
    private var isHovered = false
    private var isPressed = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        window?.acceptsMouseMovedEvents = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited, .leftMouseDown, .leftMouseUp, .leftMouseDragged]) { [weak self] event in
            self?.handle(event) ?? event
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func stopMonitoring() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        if isHovered { onHover?(false) }
        isHovered = false
        isPressed = false
    }

    // MARK: - Handle Pointer Event
    private func handle(_ event: NSEvent) -> NSEvent? {
        guard event.window === window else { return event }
        let point = convert(event.locationInWindow, from: nil)
        let inside = bounds.contains(point)
        switch event.type {
        case .leftMouseDown where inside:
            isPressed = true
            return nil
        case .leftMouseUp where isPressed:
            isPressed = false
            if inside { onClick?() }
            return nil
        default:
            if inside != isHovered {
                isHovered = inside
                onHover?(inside)
            }
            return event
        }
    }
}

// MARK: - Glossy Notice Rivet
private struct GlossyNoticeRivet: View {
    let color: Color
    let isPulsing: Bool
    let isHovered: Bool

    // MARK: - Body
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(#colorLiteral(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)),
                            Color(#colorLiteral(red: 0.70, green: 0.73, blue: 0.76, alpha: 1)),
                            Color(#colorLiteral(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)),
                            Color(#colorLiteral(red: 0.53, green: 0.57, blue: 0.61, alpha: 1)),
                            Color(#colorLiteral(red: 0.91, green: 0.93, blue: 0.95, alpha: 1)),
                            Color(#colorLiteral(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)),
                        ],
                        center: .center
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.65
                )
            Circle()
                .strokeBorder(.white, lineWidth: 0.5)
                .padding(1.35)
            Circle()
                .fill(
                    RadialGradient(
                        colors: isPulsing
                            ? [color, color]
                            : [
                                Color(#colorLiteral(red: 1, green: 0.96, blue: 0.48, alpha: 1)),
                                Color(#colorLiteral(red: 1, green: 0.925, blue: 0.267, alpha: 1)),
                                Color(#colorLiteral(red: 1, green: 0.78, blue: 0.055, alpha: 1)),
                            ],
                        center: .init(x: 0.35, y: 0.2),
                        startRadius: 0,
                        endRadius: 14
                    )
                )
                .padding(2.45)
                .brightness(isHovered ? 0.12 : 0)
            Circle()
                .strokeBorder(.black.opacity(0.44), lineWidth: 0.65)
                .padding(2.45)
            Ellipse()
                .fill(LinearGradient(colors: [.white.opacity(0.78), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                .frame(width: 9, height: 4)
                .offset(y: -4.1)
        }
        .shadow(color: isPulsing ? color.opacity(0.38) : .black.opacity(0.24), radius: isPulsing ? 3.5 : 1.6, y: 1)
    }
}

// MARK: - DevBuildCatMedallion

private struct DevBuildCatMedallion: View {
    // MARK: - Body

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(.ultraThickMaterial)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.92), Color.blue.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("🐈")
                .font(.system(size: 15))
                .fixedSize()
                .offset(y: -0.5)
        }
        .frame(width: 24, height: 24)
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white, Color.blue.opacity(0.22), Color.black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.75))
                .frame(width: 15, height: 0.75)
                .padding(.top, 1.5)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.14), radius: 1.75, x: 0, y: 1.25)
    }
}
