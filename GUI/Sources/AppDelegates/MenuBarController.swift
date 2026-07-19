// MenuBarController.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Animated memory status item that only raises the main application window.

import AppKit
import Darwin.Mach

// MARK: - Menu Bar Controller
@MainActor final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var animationTimer: Timer?
    private var animationPhase: Double = 0
    private var animationTickCount = 0
    private var currentMemoryLabel = "0M"
    private let iconCanvasSize = NSSize(width: 25, height: 24)

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
        button.action = #selector(raiseApplication)
        button.sendAction(on: [.leftMouseUp])
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageLeading
        button.font = NSFont.menuBarFont(ofSize: 9)
        button.toolTip = "MiMiNavigator"
        button.setAccessibilityLabel("Show MiMiNavigator")
        item.menu = nil
        item.isVisible = true
        statusItem = item
        refreshMemoryLabel()
        updateStatusImage()
        startAnimation()
        log.info("[MenuBar] animated memory status item installed visible=\(item.isVisible)")
        DispatchQueue.main.async { [weak self] in
            self?.logStatusItemState()
        }
    }

    // MARK: - Raise Application
    @objc private func raiseApplication() {
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

    // MARK: - Animation
    private func startAnimation() {
        animationTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(animationTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc private func animationTick() {
        animationPhase = (animationPhase + 0.08).truncatingRemainder(dividingBy: 1)
        animationTickCount += 1
        if animationTickCount.isMultiple(of: 20) { refreshMemoryLabel() }
        updateStatusImage()
    }

    // MARK: - Status Image
    private func updateStatusImage() {
        guard let button = statusItem?.button else { return }
        let image = NSImage(size: iconCanvasSize)
        image.lockFocus()
        let iconRect = NSRect(x: 1.5, y: 0.5, width: 22, height: 22)
        NSApp.applicationIconImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        drawActivityPulse()
        image.unlockFocus()
        image.isTemplate = false
        button.image = image
        button.title = currentMemoryLabel
        button.toolTip = "MiMiNavigator — \(currentMemoryLabel) memory"
    }

    private func drawActivityPulse() {
        let intensity = 0.42 + 0.30 * (sin(animationPhase * .pi * 2) + 1) / 2
        let dotRect = NSRect(x: 20, y: 18.5, width: 3.5, height: 3.5)
        NSColor.controlAccentColor.withAlphaComponent(intensity).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        NSColor.white.withAlphaComponent(0.72).setStroke()
        let border = NSBezierPath(ovalIn: dotRect.insetBy(dx: 0.35, dy: 0.35))
        border.lineWidth = 0.5
        border.stroke()
    }

    private func refreshMemoryLabel() {
        currentMemoryLabel = ByteCountFormatter.string(
            fromByteCount: Int64(residentMemoryBytes),
            countStyle: .memory
        )
    }

    private var residentMemoryBytes: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
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
