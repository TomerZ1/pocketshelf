import AppKit

// Detects a horizontal shake gesture during any left-mouse drag.
// Fires onShake when 3+ directional reversals of ≥20 px each occur within 600 ms.
final class ShakeDetector {
    var onShake: (() -> Void)?
    private var monitors: [Any] = []
    private var samples: [(x: CGFloat, t: TimeInterval)] = []

    init() { setup() }

    deinit { monitors.forEach { NSEvent.removeMonitor($0) } }

    private func setup() {
        // Global monitors work for events in other apps without Accessibility permission
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] _ in
            self?.record(x: NSEvent.mouseLocation.x)
        }) { monitors.append(m) }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            self?.samples.removeAll()
        }) { monitors.append(m) }
    }

    private func record(x: CGFloat) {
        let t = ProcessInfo.processInfo.systemUptime
        samples = samples.filter { t - $0.t < 0.6 }
        samples.append((x, t))
        guard samples.count >= 6 else { return }
        if detectShake() {
            samples.removeAll()
            DispatchQueue.main.async { self.onShake?() }
        }
    }

    private func detectShake() -> Bool {
        var segments = 0
        var lastDir: CGFloat = 0
        var segDist: CGFloat = 0

        for i in 1..<samples.count {
            let dx = samples[i].x - samples[i-1].x
            guard abs(dx) > 1 else { continue }
            let dir: CGFloat = dx > 0 ? 1 : -1
            if lastDir == 0 {
                lastDir = dir; segDist = abs(dx)
            } else if dir == lastDir {
                segDist += abs(dx)
            } else {
                if segDist > 20 { segments += 1 }
                lastDir = dir; segDist = abs(dx)
            }
        }
        if segDist > 20 { segments += 1 }
        return segments >= 3
    }
}
