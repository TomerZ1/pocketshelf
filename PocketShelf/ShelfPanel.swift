import AppKit

// GlowContainerView is a masksToBounds=false wrapper so CALayer shadows (neon glow)
// aren't clipped — the ShelfView inside does its own corner clipping.
private final class GlowContainerView: NSView {
    private let glowLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        // Do NOT set masksToBounds — the shadow must overflow the view bounds

        glowLayer.cornerRadius   = 18
        glowLayer.backgroundColor = NSColor.clear.cgColor
        glowLayer.borderColor    = NSColor(srgbRed: 0.60, green: 0.50, blue: 1.0, alpha: 0.45).cgColor
        glowLayer.borderWidth    = 1.0
        glowLayer.shadowColor    = NSColor(srgbRed: 0.50, green: 0.38, blue: 0.95, alpha: 1.0).cgColor
        glowLayer.shadowRadius   = 20
        glowLayer.shadowOpacity  = 0.55
        glowLayer.shadowOffset   = .zero
        layer?.addSublayer(glowLayer)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        glowLayer.frame      = bounds
        glowLayer.shadowPath = CGPath(roundedRect: bounds, cornerWidth: 18, cornerHeight: 18, transform: nil)
    }
}

final class ShelfPanel: NSPanel {
    private let shelfView: ShelfView
    private let glowContainer: GlowContainerView

    init() {
        shelfView     = ShelfView()
        glowContainer = GlowContainerView(frame: .zero)

        let size = shelfView.intrinsicContentSize
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level            = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque         = false
        backgroundColor  = .clear
        hasShadow        = false   // panel shadow off; glow layer provides it
        isMovableByWindowBackground = true

        glowContainer.addSubview(shelfView)
        contentView = glowContainer

        shelfView.onItemsChanged    = { [weak self] in self?.sizeToFit() }
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
        contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.94, y: 0.94))
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue          = CATransform3DMakeScale(0.94, 0.94, 1)
        scale.toValue            = CATransform3DIdentity
        scale.duration           = 0.2
        scale.timingFunction     = CAMediaTimingFunction(name: .easeOut)
        scale.fillMode           = .forwards
        scale.isRemovedOnCompletion = true
        contentView?.wantsLayer  = true
        contentView?.layer?.add(scale, forKey: "showScale")
        contentView?.layer?.setAffineTransform(.identity)
    }

    // Spring bounce used when triggered by shake gesture
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
        glowContainer.frame = NSRect(origin: .zero, size: size)
        shelfView.frame     = NSRect(origin: .zero, size: size)
    }

    private func clampedOrigin(_ origin: NSPoint) -> NSPoint {
        guard let screen = NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let x = max(visible.minX, min(origin.x, visible.maxX - frame.width))
        let y = max(visible.minY, min(origin.y, visible.maxY - frame.height))
        return NSPoint(x: x, y: y)
    }
}
