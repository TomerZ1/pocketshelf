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
        shelfView.onItemsChanged = { [weak self] in
            self?.sizeToFit()
        }
    }

    func showNearCursor() {
        let mouse = NSEvent.mouseLocation
        sizeToFit()
        let origin = NSPoint(x: mouse.x - frame.width / 2, y: mouse.y - frame.height - 8)
        setFrameOrigin(clampedOrigin(origin))
        makeKeyAndOrderFront(nil)
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
