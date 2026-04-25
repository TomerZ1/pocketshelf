import AppKit

private let kColumns: CGFloat = 4
private let kThumbSize: CGFloat = 52
private let kRadius: CGFloat = 9
private let kGap: CGFloat = 8
private let kPadding: CGFloat = 12
private let kCaptionHeight: CGFloat = 14
private let kItemHeight: CGFloat = kThumbSize + kGap + kCaptionHeight
private let kPanelWidth: CGFloat = kPadding * 2 + kColumns * kThumbSize + (kColumns - 1) * kGap
private let kEmptyHeight: CGFloat = 96
private let kMaxRows: CGFloat = 2

final class ShelfView: NSView {
    var onItemsChanged: (() -> Void)?
    private var items: [ShelfItem] = []
    private let effectView = NSVisualEffectView()
    private let emptyLabel = NSTextField(labelWithString: "Drop files here")
    private var itemViews: [ShelfItemView] = []
    private let clearButton = NSButton()

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
        layer?.cornerRadius = 18
        layer?.masksToBounds = true

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 18
        effectView.layer?.masksToBounds = true
        addSubview(effectView)

        emptyLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        emptyLabel.textColor = NSColor.secondaryLabelColor
        emptyLabel.alignment = .center
        addSubview(emptyLabel)

        clearButton.title = ""
        clearButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Clear")
        clearButton.bezelStyle = .regularSquare
        clearButton.isBordered = false
        clearButton.contentTintColor = .secondaryLabelColor
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
        emptyLabel.isHidden = !items.isEmpty
        clearButton.isHidden = items.isEmpty
        layout()

        for (i, item) in items.enumerated() {
            let view = ShelfItemView(item: item)
            view.onDragOut = { [weak self] removed in
                if removed { self?.remove(item: item) }
            }
            addSubview(view)
            itemViews.append(view)
            positionItemView(view, at: i)
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
        let lw: CGFloat = 120
        emptyLabel.frame = NSRect(x: (s.width - lw) / 2, y: (s.height - 16) / 2, width: lw, height: 16)
        clearButton.frame = NSRect(x: s.width - 26, y: s.height - 26, width: 20, height: 20)
    }

    private func remove(item: ShelfItem) {
        items.removeAll { $0 === item }
        reload()
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.borderWidth = 1.5
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
        return .link
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        layer?.borderWidth = 0
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.borderWidth = 0
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else { return false }
        for url in urls {
            items.append(ShelfItem(url: url))
        }
        reload()
        return true
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
        thumbView.layer?.cornerRadius = kRadius
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
        let removed = !operation.isEmpty
        onDragOut?(removed)
    }
}
