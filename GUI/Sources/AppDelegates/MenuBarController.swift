// MenuBarController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Animated memory status item that toggles the main window and provides safe termination.

import AppKit

// MARK: - Menu Bar Controller
@MainActor final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var animationTimer: Timer?
    private var animationPhase: Double = 0
    private var animationTickCount = 0
    private var currentMemoryLabel = "0 MB"
    private var animationFrames: [NSImage] = []
    private let iconCanvasSize = NSSize(width: 25, height: 24)
    private let animationFrameCount = 12

    // MARK: - Install
    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            log.error("[MenuBar] status item button unavailable")
            return
        }
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageLeading
        button.font = NSFont.menuBarFont(ofSize: 9)
        button.toolTip = "MiMiNavigator"
        button.setAccessibilityLabel("Show or minimize MiMiNavigator")
        item.menu = nil
        item.isVisible = true
        statusItem = item
        animationFrames = makeAnimationFrames()
        refreshMemoryLabel()
        updateStatusImage()
        startAnimation()
        log.info("[MenuBar] animated memory status item installed visible=\(item.isVisible)")
        DispatchQueue.main.async { [weak self] in
            self?.logStatusItemState()
        }
    }

    // MARK: - Status Item Actions
    @objc private func handleStatusItemClick() {
        guard NSApp.currentEvent?.type != .rightMouseUp else {
            showQuitMenu()
            return
        }
        toggleApplicationVisibility()
    }

    private func toggleApplicationVisibility() {
        if let window = existingMainWindow,
           window.isVisible,
           !window.isMiniaturized,
           window.isKeyWindow,
           NSApp.isActive
        {
            window.miniaturize(nil)
            log.info("[MenuBar] minimized main window to Dock")
            return
        }
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let window = existingMainWindow {
            raise(window)
        } else {
            NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
        }
        DispatchQueue.main.async { [weak self] in self?.raiseExistingMainWindow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.raiseExistingMainWindow() }
    }

    private func showQuitMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        let quitItem = NSMenuItem(title: "Quit MiMiNavigator", action: #selector(quitApplication), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 2), in: button)
    }

    @objc private func quitApplication() {
        log.info("[MenuBar] quit requested")
        NSApp.terminate(nil)
    }

    // MARK: - Animation
    private func startAnimation() {
        animationTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, target: self, selector: #selector(animationTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc private func animationTick() {
        animationPhase = (animationPhase + 1 / Double(animationFrameCount)).truncatingRemainder(dividingBy: 1)
        animationTickCount += 1
        if animationTickCount.isMultiple(of: 8) { refreshMemoryLabel() }
        updateStatusImage()
    }

    // MARK: - Status Image
    private func updateStatusImage() {
        guard let button = statusItem?.button else { return }
        if animationFrames.isEmpty {
            button.image = NSApp.applicationIconImage
        } else {
            let frameIndex = min(Int(animationPhase * Double(animationFrameCount)), animationFrames.count - 1)
            button.image = animationFrames[frameIndex]
        }
        button.title = currentMemoryLabel
        button.toolTip = "MiMiNavigator — \(currentMemoryLabel) memory"
    }

    private func makeAnimationFrames() -> [NSImage] {
        guard let applicationIcon = NSApp.applicationIconImage else { return [] }
        let baseIcon = applicationIcon.copy() as? NSImage ?? applicationIcon
        return (0..<animationFrameCount).map {
            index in
                let phase = Double(index) / Double(animationFrameCount)
                let image = NSImage(size: iconCanvasSize)
                image.lockFocus()
                let iconRect = NSRect(x: 1.5, y: 0.5, width: 22, height: 22)
                baseIcon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
                drawActivityPulse(phase: phase)
                image.unlockFocus()
                image.isTemplate = false
                return image
        }
    }

    private func drawActivityPulse(phase: Double) {
        let intensity = 0.42 + 0.30 * (sin(phase * .pi * 2) + 1) / 2
        let dotRect = NSRect(x: 20, y: 18.5, width: 3.5, height: 3.5)
        NSColor.controlAccentColor.withAlphaComponent(intensity).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        NSColor.white.withAlphaComponent(0.72).setStroke()
        let border = NSBezierPath(ovalIn: dotRect.insetBy(dx: 0.35, dy: 0.35))
        border.lineWidth = 0.5
        border.stroke()
    }

    private func refreshMemoryLabel() {
        currentMemoryLabel = MemoryDiagnostics.wholeMemoryLabel(bytes: MemoryDiagnostics.capture().residentBytes)
    }

    private var existingMainWindow: NSWindow? {
        let windows = NSApp.windows.filter { !($0 is NSPanel) && $0.styleMask.contains(.titled) }
        return windows.first { $0.identifier?.rawValue.hasPrefix("main-AppWindow") == true }
            ?? windows.first { $0.isMiniaturized || $0.isVisible }
    }

    // MARK: - Raise Main Window
    private func raiseExistingMainWindow() {
        guard let window = existingMainWindow else {
            log.error("[MenuBar] main window unavailable after activation")
            return
        }
        raise(window)
    }

    private func raise(_ window: NSWindow) {
        let wasMiniaturized = window.isMiniaturized
        if wasMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.arrangeInFront(nil)
        log.info(
            "[MenuBar] raised main window id='\(window.identifier?.rawValue ?? "nil")' minimized=\(wasMiniaturized) visible=\(window.isVisible)"
        )
    }

    // MARK: - Log State
    private func logStatusItemState() {
        guard let item = statusItem, let button = item.button else {
            log.error("[MenuBar] status item lost after installation")
            return
        }
        let frame = button.window?.frame ?? .zero
        log.info("[MenuBar] status item ready visible=\(item.isVisible) windowVisible=\(button.window?.isVisible == true) frame=\(NSStringFromRect(frame))")
    }
}
