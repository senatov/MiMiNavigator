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
    private var animationPhase = false
    private let iconCanvasSize = NSSize(width: 36, height: 24)

    // MARK: - Install
    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: 38)
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            log.error("[MenuBar] status item button unavailable")
            return
        }
        button.target = self
        button.action = #selector(raiseApplication)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.toolTip = "MiMiNavigator"
        button.setAccessibilityLabel("Show MiMiNavigator")
        item.menu = nil
        item.isVisible = true
        statusItem = item
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
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)
        }
        log.info("[MenuBar] raised main window")
    }

    // MARK: - Animation
    private func startAnimation() {
        animationTimer?.invalidate()
        let timer = Timer(timeInterval: 0.8, target: self, selector: #selector(animationTick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc private func animationTick() {
        animationPhase.toggle()
        updateStatusImage()
    }

    // MARK: - Status Image
    private func updateStatusImage() {
        guard let button = statusItem?.button else { return }
        let image = NSImage(size: iconCanvasSize)
        image.lockFocus()
        let iconSize: CGFloat = animationPhase ? 22.5 : 21.5
        let iconRect = NSRect(x: 1.5, y: animationPhase ? 0.8 : 0.2, width: iconSize, height: iconSize)
        NSApp.applicationIconImage.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        drawMemoryLabel(memoryLabel, in: NSRect(x: 18, y: 3, width: 17, height: 10))
        image.unlockFocus()
        image.isTemplate = false
        button.image = image
        button.toolTip = "MiMiNavigator — \(memoryLabel) memory"
    }

    private func drawMemoryLabel(_ text: String, in rect: NSRect) {
        let background = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        NSColor.black.withAlphaComponent(0.78).setFill()
        background.fill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 6.5, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        text.draw(in: rect.offsetBy(dx: 0, dy: 1.2), withAttributes: attributes)
    }

    private var memoryLabel: String {
        let bytes = residentMemoryBytes
        let megabytes = bytes / 1_048_576
        if megabytes < 1_000 { return "\(megabytes)M" }
        return String(format: "%.1fG", Double(bytes) / 1_073_741_824)
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
        NSApp.windows.first {
            !($0 is NSPanel) && $0.styleMask.contains(.titled) && $0.canBecomeMain
        }
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
