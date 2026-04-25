import AppKit

private let kColumns: CGFloat = 4
private let kThumbSize: CGFloat = 52
private let kThumbRadius: CGFloat = 9
private let kGap: CGFloat = 8
private let kPadding: CGFloat = 12
private let kCaptionHeight: CGFloat = 14
private let kItemHeight: CGFloat = kThumbSize + kGap + kCaptionHeight
private let kPanelWidth: CGFloat = kPadding * 2 + kColumns * kThumbSize + (kColumns - 1) * kGap
private let kEmptyHeight: CGFloat = 96
private let kPanelRadius: CGFloat = 18

// Glass edge color: very subtle white border matching the frosted glass aesthetic
private let kGlassBorderColor = NSColor.white.withAlphaComponent(0.10).cgColor
private let kGlowBorderColor  = NSColor.systemBlue.withAlphaComponent(0.65).cgColor

final class ShelfView: NSView {
    var onItemsChanged: (() -> Void)?
    private var items: [ShelfItem] = []
    private let effectView = NSVisualEffectView()
    private let emptyLabel = NSTextField(labelWithString: "Drop files here")
    private var itemViews: [ShelfItemView] = []
    private let clearButton = NSButton()
    private let dashedBorderLayer = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        if items.isEmpty {
            return NSSize(width: kPanelWidth, height: kEmptyHeight)
        }
        let rows = ceil(CGFloat(items.count) / kColumns)
        let h = kPadding + rows * kItemHeight + (rows - 1) * kGap + kPadding
        return NSSize(width: kPanelWidth, height: h)
    }

    func clearItems() {
        items.removeAll()
        reload()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = kPanelRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = kGlassBorderColor

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = kPanelRadius
        effectView.layer?.masksToBounds = true
        addSubview(effectView)

        // Dashed drop-target border, only visible in empty state
        dashedBorderLayer.fillColor = nil
        dashedBorderLayer.strokeColor = NSColor.white.withAlphaComponent(0.22).cgColor
        dashedBorderLayer.lineWidth = 1
        dashedBorderLayer.lineDashPattern = [6, 4]
        dashedBorderLayer.cornerRadius = 10
        layer?.addSublayer(dashedBorderLayer)

        emptyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        emptyLabel.textColor = NSColor.secondaryLabelColor
        emptyLabel.alignment = .center
        addSubview(emptyLabel)

        clearButton.title = ""
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        clearButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Clear")?.withSymbolConfiguration(config)
        clearButton.bezelStyle = .regularSquare
        clearButton.isBordered = false
        clearButton.contentTintColor = NSColor.tertiaryLabelColor
        clearButton.target = self
        clearButton.action = #selector(clearTapped)
        addSubview(clearButton)

        registerForDraggedTypes([.fileURL])
        reload()
    }

    @objc private func clearTapped() {
        clearItems()
    }

    private func reload() {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()

        let empty = items.isEmpty
        emptyLabel.isHidden = !empty
        dashedBorderLayer.isHidden = !empty
        clearButton.isHidden = empty

        layout()

        for (i, item) in items.enumerated() {
            let view = ShelfItemView(item: item)
            view.onDragOut = { [weak self] removed in
                if removed { self?.remove(item: item) }
            }
            addSubview(view)
            itemViews.append(view)
            positionItemView(view, at: i)
            // Fade each item in
            view.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                view.animator().alphaValue = 1
            }
        }
        invalidateIntrinsicContentSize()
        onItemsChanged?()
    }

    private func positionItemView(_ view: ShelfItemView, at index: Int) {
        let col = CGFloat(index % Int(kColumns))
        let row = CGFloat(index / Int(kColumns))
        let x = kPadding + col * (kThumbSize + kGap)
        let h = intrinsicContentSize.height
        let y = h - kPadding - (row + 1) * kItemHeight - row * kGap
        view.frame = NSRect(x: x, y: y, width: kThumbSize, height: kItemHeight)
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds

        let s = intrinsicContentSize
        let inset: CGFloat = 10
        dashedBorderLayer.frame = CGRect(x: inset, y: inset, width: s.width - inset * 2, height: s.height - inset * 2)
        dashedBorderLayer.path = CGPath(roundedRect: dashedBorderLayer.bounds, cornerWidth: 10, cornerHeight: 10, transform: nil)

        let lw: CGFloat = 120
        emptyLabel.frame = NSRect(x: (s.width - lw) / 2, y: (s.height - 16) / 2, width: lw, height: 16)
        clearButton.frame = NSRect(x: s.width - 24, y: s.height - 24, width: 18, height: 18)
    }

    private func remove(item: ShelfItem) {
        items.removeAll { $0 === item }
        reload()
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setBorderGlow(true)
        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setBorderGlow(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setBorderGlow(false)
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return false }
        for url in urls {
            items.append(ShelfItem(url: url))
        }
        reload()
        return true
    }

    private func setBorderGlow(_ on: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        layer?.borderColor = on ? kGlowBorderColor : kGlassBorderColor
        layer?.borderWidth  = on ? 1.5 : 0.5
        CATransaction.commit()
    }
}

// MARK: - ShelfItemView

private final class ShelfItemView: NSView, NSDraggingSource {
    var onDragOut: ((Bool) -> Void)?
    private let item: ShelfItem
    private let thumbView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init(item: ShelfItem) {
        self.item = item
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        thumbView.image = item.icon
        thumbView.imageScaling = .scaleProportionallyUpOrDown
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = kThumbRadius
        thumbView.layer?.masksToBounds = true
        addSubview(thumbView)

        label.stringValue = item.filename
        label.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingMiddle
        addSubview(label)
    }

    override func layout() {
        super.layout()
        thumbView.frame = NSRect(x: 0, y: bounds.height - kThumbSize, width: kThumbSize, height: kThumbSize)
        label.frame = NSRect(x: 0, y: 0, width: kThumbSize, height: kCaptionHeight)
    }

    // MARK: - Drag out

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        let pb = NSPasteboardItem()
        pb.setString(item.url.absoluteString, forType: .fileURL)
        let draggingItem = NSDraggingItem(pasteboardWriter: pb)
        draggingItem.setDraggingFrame(thumbView.frame, contents: item.icon)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return context == .outsideApplication ? [.copy, .move, .link] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDragOut?(!operation.isEmpty)
    }
}
