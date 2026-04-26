import AppKit

// The glow panel is larger than the shelf content by kGlowInset on each side,
// giving the neon CALayer shadow room to render outside the shelf bounds without
// being clipped by the window frame.
private let kGlowInset: CGFloat = 14

// GlowContainerView sits behind ShelfView and is NOT masksToBounds so its shadow
// overflows. ShelfView inside it does its own corner clipping independently.
private final class GlowContainerView: NSView {
    private let glowLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false

        glowLayer.cornerRadius    = 18
        glowLayer.backgroundColor = NSColor.clear.cgColor
        glowLayer.borderColor     = NSColor(srgbRed: 0.65, green: 0.52, blue: 1.0, alpha: 0.80).cgColor
        glowLayer.borderWidth     = 1.5
        glowLayer.shadowColor     = NSColor(srgbRed: 0.55, green: 0.40, blue: 1.0, alpha: 1.0).cgColor
        glowLayer.shadowRadius    = 10
        glowLayer.shadowOpacity   = 0.90
        glowLayer.shadowOffset    = .zero
        layer?.addSublayer(glowLayer)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        // Position glowLayer inset from container — the shadow overflows into the inset margin
        let f = bounds.insetBy(dx: kGlowInset, dy: kGlowInset)
        glowLayer.frame      = f
        glowLayer.shadowPath = CGPath(
            roundedRect: glowLayer.bounds,
            cornerWidth: 18, cornerHeight: 18, transform: nil
        )
    }
}

final class ShelfPanel: NSPanel {
    private let shelfView: ShelfView
    private let glowContainer: GlowContainerView

    init() {
        shelfView     = ShelfView()
        glowContainer = GlowContainerView(frame: .zero)

        let sz    = shelfView.intrinsicContentSize
        let padSz = NSSize(width: sz.width + kGlowInset*2, height: sz.height + kGlowInset*2)
        let rect  = NSRect(origin: .zero, size: padSz)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level              = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque           = false
        backgroundColor    = .clear
        hasShadow          = false   // glow layer provides the shadow
        isMovableByWindowBackground = false

        glowContainer.addSubview(shelfView)
        contentView = glowContainer

        shelfView.onItemsChanged     = { [weak self] in self?.sizeToFit() }
        shelfView.onDismissRequested = { [weak self] in self?.hide() }
    }

    var isEmpty: Bool { shelfView.isEmpty }

    func show() {
        sizeToFit()
        let mouse = NSEvent.mouseLocation
        // Align visible shelf content 8 px below cursor (not the glow padding)
        let origin = NSPoint(
            x: mouse.x - frame.width / 2,
            y: mouse.y - shelfView.frame.height - kGlowInset - 8
        )
        if !isVisible { setFrameOrigin(clampedOrigin(origin)) }
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
        let origin = NSPoint(
            x: mouse.x - frame.width / 2,
            y: mouse.y - shelfView.frame.height - kGlowInset - 12
        )
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

    func clearItems() { shelfView.clearItems() }

    private func sizeToFit() {
        let sz    = shelfView.intrinsicContentSize
        let padSz = NSSize(width: sz.width + kGlowInset*2, height: sz.height + kGlowInset*2)
        setContentSize(padSz)
        glowContainer.frame = NSRect(origin: .zero, size: padSz)
        shelfView.frame     = NSRect(x: kGlowInset, y: kGlowInset, width: sz.width, height: sz.height)
    }

    private func clampedOrigin(_ origin: NSPoint) -> NSPoint {
        guard let screen = NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let x = max(visible.minX, min(origin.x, visible.maxX - frame.width))
        let y = max(visible.minY, min(origin.y, visible.maxY - frame.height))
        return NSPoint(x: x, y: y)
    }
}
