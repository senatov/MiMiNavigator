import Foundation

// MARK: - Main queue responsiveness
/// State belongs to the private serial queue; no AppKit access occurs off the main thread.
final class ResponsivenessDiagnostics: @unchecked Sendable {
    static let shared = ResponsivenessDiagnostics()
    private let queue = DispatchQueue(label: "MiMiNavigator.Responsiveness", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var pendingSince: UInt64?
    private var lastTick: UInt64 = 0
    private var warned = false
    private var generation = UUID()

    // MARK: - Start
    func start() {
        queue.async {
            guard self.timer == nil else { return }
            self.generation = UUID()
            self.lastTick = 0
            self.warned = false
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 3, repeating: 3, leeway: .milliseconds(200))
            timer.setEventHandler { [weak monitor = self] in monitor?.tick() }
            self.timer = timer
            timer.resume()
        }
    }

    // MARK: - Stop
    func stop() {
        queue.async {
            self.timer?.cancel()
            self.timer = nil
            self.pendingSince = nil
            self.generation = UUID()
        }
    }

    // MARK: - Ping main queue
    private func tick() {
        let now = DispatchTime.now().uptimeNanoseconds
        if lastTick > 0 && now - lastTick > 10_000_000_000 {
            let gap = String(format: "%.3f", Double(now - lastTick) / 1e9)
            log.info("[Responsiveness] monitor-gap seconds=\(gap); delay measurement reset")
            pendingSince = nil
            warned = false
            generation = UUID()
        }
        lastTick = now
        if let pendingSince {
            if !warned {
                warned = true
                let memory = MemoryDiagnostics.capture()
                let delay = String(format: "%.3f", Double(now - pendingSince) / 1e9)
                log.warning("[Responsiveness] main-queue-delayed seconds=\(delay) pid=\(ProcessInfo.processInfo.processIdentifier) threads=\(memory.threadCount) footprintMB=\(memory.footprintBytes / 1_048_576) \(DiagnosticActivity.shared.snapshot()); capture sample while delay persists")
            }
            return
        }
        pendingSince = now
        let currentGeneration = generation
        DispatchQueue.main.async {
            self.queue.async {
                guard self.generation == currentGeneration else { return }
                if self.warned, let started = self.pendingSince {
                    let delay = String(format: "%.3f", Double(DispatchTime.now().uptimeNanoseconds - started) / 1e9)
                    log.warning("[Responsiveness] main-queue-recovered seconds=\(delay) \(DiagnosticActivity.shared.snapshot())")
                }
                self.pendingSince = nil
                self.warned = false
            }
        }
    }
}
