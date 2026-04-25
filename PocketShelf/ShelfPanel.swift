import AppKit

final class ShelfPanel: NSPanel {
    private let shelfView: ShelfView

    init() {
        shelfView = ShelfView()
        let size = shelfView.intrinsicContentSize
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true

        contentView = shelfView
        shelfView.onItemsChanged = { [weak self] in self?.sizeToFit() }
        shelfView.onDismissRequested = { [weak self] in self?.hide() }
    }

    var isEmpty: Bool { shelfView.isEmpty }

    func show() {
        sizeToFit()
        let mouse = NSEvent.mouseLocation
        let origin = NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - frame.height - 8)
        if !isVisible {
            setFrameOrigin(clampedOrigin(origin))
        }
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        // Fade + scale in: scale is applied to the content view's layer
        contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.94, y: 0.94))
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        // Animate scale back to 1 via Core Animation
        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue = CATransform3DMakeScale(0.94, 0.94, 1)
        scale.toValue = CATransform3DIdentity
        scale.duration = 0.2
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        scale.fillMode = .forwards
        scale.isRemovedOnCompletion = true
        contentView?.wantsLayer = true
        contentView?.layer?.add(scale, forKey: "showScale")
        contentView?.layer?.setAffineTransform(.identity)
    }

    // Spring bounce used when triggered by shake gesture — more energetic than the hotkey fade
    func showWithSpring() {
        sizeToFit()
        let mouse = NSEvent.mouseLocation
        let origin = NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - frame.height - 12)
        setFrameOrigin(clampedOrigin(origin))
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        let spring = CASpringAnimation(keyPath: "transform")
        spring.fromValue       = CATransform3DMakeScale(0.72, 0.72, 1)
        spring.toValue         = CATransform3DIdentity
        spring.damping         = 12
        spring.stiffness       = 200
        spring.initialVelocity = 8
        spring.duration        = spring.settlingDuration
        contentView?.wantsLayer = true
        contentView?.layer?.add(spring, forKey: "springScale")
        contentView?.layer?.setAffineTransform(.identity)
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }

    func clearItems() {
        shelfView.clearItems()
    }

    private func sizeToFit() {
        let size = shelfView.intrinsicContentSize
        setContentSize(size)
    }

    private func clampedOrigin(_ origin: NSPoint) -> NSPoint {
        guard let screen = NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let x = max(visible.minX, min(origin.x, visible.maxX - frame.width))
        let y = max(visible.minY, min(origin.y, visible.maxY - frame.height))
        return NSPoint(x: x, y: y)
    }
}
