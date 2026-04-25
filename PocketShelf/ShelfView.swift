import AppKit

// MARK: - Layout constants

private let kCols          = 4
private let kPanelW: CGFloat  = 280
private let kSidePad: CGFloat = 10
private let kGridPad: CGFloat = 2
private let kGap: CGFloat     = 8
private let kTileW: CGFloat   = (kPanelW - kSidePad*2 - kGridPad*2 - kGap*CGFloat(kCols-1)) / CGFloat(kCols)
private let kThumbSize: CGFloat   = 52
private let kThumbRadius: CGFloat = 9
private let kTileInnerGap: CGFloat = 4
private let kCaptionH: CGFloat = 14
private let kTileH: CGFloat    = kThumbSize + kTileInnerGap + kCaptionH
private let kHeaderH: CGFloat  = 26
private let kHeaderTopPad: CGFloat   = 8
private let kAfterHeaderGap: CGFloat = 6
private let kPanelRadius: CGFloat = 18
private let kBottomPad: CGFloat   = 10
private let kEmptyStateH: CGFloat = 100

private func panelHeight(for count: Int) -> CGFloat {
    if count == 0 {
        return kHeaderTopPad + kHeaderH + kAfterHeaderGap + kEmptyStateH + kBottomPad
    }
    let rows = CGFloat((count + kCols - 1) / kCols)
    return kHeaderTopPad + kHeaderH + kAfterHeaderGap
         + kGridPad + rows*kTileH + (rows-1)*kGap + kGridPad
         + kBottomPad
}

private let kDarkTop      = NSColor(srgbRed: 50/255, green: 52/255, blue: 60/255, alpha: 0.78).cgColor
private let kDarkBot      = NSColor(srgbRed: 36/255, green: 38/255, blue: 46/255, alpha: 0.82).cgColor
private let kGlassBorder  = NSColor.white.withAlphaComponent(0.10).cgColor
private let kGlowBorder   = NSColor.systemBlue.withAlphaComponent(0.65).cgColor
private let kAccent       = NSColor(srgbRed: 0x5e/255, green: 0x6a/255, blue: 0xd2/255, alpha: 1)
private let kSelFill      = NSColor(srgbRed: 0x5e/255, green: 0x6a/255, blue: 0xd2/255, alpha: 0.15)
private let kSelStroke    = NSColor(srgbRed: 0x5e/255, green: 0x6a/255, blue: 0xd2/255, alpha: 0.55)

// MARK: - ShelfView

final class ShelfView: NSView {
    var onItemsChanged: (() -> Void)?
    var onDismissRequested: (() -> Void)?
    var isEmpty: Bool { items.isEmpty }

    private var items: [ShelfItem] = []
    private let effectView  = NSVisualEffectView()
    private let tintView    = GradientOverlayView()
    private let headerView  = ShelfHeaderView()
    private let emptyState  = ShelfEmptyStateView()
    private var itemViews: [ShelfItemView] = []

    // Selection state
    private var selectedIndices: Set<Int> = []
    private var selectionStart: NSPoint?
    private let selectionLayer = CAShapeLayer()

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: kPanelW, height: panelHeight(for: items.count))
    }

    func clearItems() { items.removeAll(); selectedIndices.removeAll(); reload() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius  = kPanelRadius
        layer?.masksToBounds = true
        layer?.borderWidth   = 0.5
        layer?.borderColor   = kGlassBorder

        effectView.material     = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state        = .active
        effectView.appearance   = NSAppearance(named: .darkAqua)
        effectView.wantsLayer   = true
        effectView.layer?.cornerRadius  = kPanelRadius
        effectView.layer?.masksToBounds = true
        addSubview(effectView)

        tintView.gradColors = [kDarkTop, kDarkBot]
        addSubview(tintView)

        // Rubber-band selection layer
        selectionLayer.fillColor   = kSelFill.cgColor
        selectionLayer.strokeColor = kSelStroke.cgColor
        selectionLayer.lineWidth   = 1
        selectionLayer.cornerRadius = 4
        selectionLayer.isHidden    = true
        layer?.addSublayer(selectionLayer)

        headerView.onClear = { [weak self] in
            self?.clearItems()
            self?.onDismissRequested?()
        }
        addSubview(headerView)
        addSubview(emptyState)

        registerForDraggedTypes([.fileURL])
        reload()
    }

    private func reload() {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews.removeAll()
        emptyState.isHidden  = !items.isEmpty
        headerView.itemCount = items.count

        for (i, item) in items.enumerated() {
            let idx = i
            let v = ShelfItemView(item: item)
            v.onMouseDown = { [weak self] event in self?.handleItemMouseDown(at: idx, event: event) }
            v.onDragOut   = { [weak self] draggedItems, removed in
                guard removed else { return }
                self?.removeItems(draggedItems)
            }
            v.getSelectedItems = { [weak self] () -> [ShelfItem] in
                guard let self else { return [item] }
                if self.selectedIndices.contains(idx) {
                    return self.selectedIndices.sorted().compactMap {
                        self.items.indices.contains($0) ? self.items[$0] : nil
                    }
                }
                return [item]
            }
            addSubview(v)
            itemViews.append(v)
            v.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                v.animator().alphaValue = 1
            }
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
        onItemsChanged?()
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        let h = bounds.height
        effectView.frame = bounds
        tintView.frame   = bounds

        let headerY = h - kHeaderTopPad - kHeaderH
        headerView.frame = NSRect(x: kSidePad, y: headerY, width: w - kSidePad*2, height: kHeaderH)
        emptyState.frame = NSRect(x: kSidePad, y: kBottomPad, width: w - kSidePad*2, height: kEmptyStateH)

        let gridTop = headerY - kAfterHeaderGap - kGridPad
        for (i, v) in itemViews.enumerated() {
            let col = CGFloat(i % kCols)
            let row = CGFloat(i / kCols)
            let x = kSidePad + kGridPad + col*(kTileW + kGap)
            let y = gridTop - (row+1)*kTileH - row*kGap
            v.frame = NSRect(x: x, y: y, width: kTileW, height: kTileH)
        }
    }

    private func removeItems(_ toRemove: [ShelfItem]) {
        items.removeAll { item in toRemove.contains { $0 === item } }
        selectedIndices.removeAll()
        reload()
    }

    // MARK: - Item selection

    private func handleItemMouseDown(at idx: Int, event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if selectedIndices.contains(idx) { selectedIndices.remove(idx) }
            else { selectedIndices.insert(idx) }
        } else {
            selectedIndices = selectedIndices.contains(idx) ? selectedIndices : [idx]
        }
        updateSelectionVisuals()
    }

    private func updateSelectionVisuals() {
        for (i, v) in itemViews.enumerated() {
            v.isSelected = selectedIndices.contains(i)
        }
    }

    // MARK: - Rubber-band selection

    override func mouseDown(with event: NSEvent) {
        // Fires only for background clicks (item views intercept item area clicks)
        if !event.modifierFlags.contains(.command) {
            selectedIndices.removeAll()
            updateSelectionVisuals()
        }
        selectionStart = convert(event.locationInWindow, from: nil)
        selectionLayer.isHidden = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = selectionStart else { return }
        let pt = convert(event.locationInWindow, from: nil)
        let rect = NSRect(
            x: min(start.x, pt.x), y: min(start.y, pt.y),
            width: abs(pt.x - start.x), height: abs(pt.y - start.y)
        )
        selectionLayer.frame = rect
        selectionLayer.path  = CGPath(roundedRect: selectionLayer.bounds, cornerWidth: 4, cornerHeight: 4, transform: nil)
        selectionLayer.isHidden = rect.width < 4 && rect.height < 4

        // Select items whose thumb intersects the rubber-band rect
        var newSelection = Set<Int>()
        for (i, v) in itemViews.enumerated() {
            if rect.intersects(v.frame) { newSelection.insert(i) }
        }
        if newSelection != selectedIndices {
            selectedIndices = newSelection
            updateSelectionVisuals()
        }
    }

    override func mouseUp(with event: NSEvent) {
        selectionStart = nil
        selectionLayer.isHidden = true
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setBorderGlow(true)
        emptyState.setHovering(true)
        return .link
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        setBorderGlow(false)
        emptyState.setHovering(false)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        setBorderGlow(false)
        emptyState.setHovering(false)
        guard let urls = sender.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        else { return false }
        urls.forEach { items.append(ShelfItem(url: $0)) }
        reload()
        return true
    }
    private func setBorderGlow(_ on: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        layer?.borderColor = on ? kGlowBorder : kGlassBorder
        layer?.borderWidth  = on ? 1.5 : 0.5
        CATransaction.commit()
    }
}

// MARK: - GradientOverlayView

private final class GradientOverlayView: NSView {
    var gradColors: [CGColor] = [] { didSet { grad.colors = gradColors } }
    private let grad = CAGradientLayer()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        grad.startPoint = CGPoint(x: 0.5, y: 1.0)
        grad.endPoint   = CGPoint(x: 0.5, y: 0.0)
        layer?.addSublayer(grad)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() { super.layout(); grad.frame = bounds }
}

// MARK: - ShelfHeaderView

private final class ShelfHeaderView: NSView {
    var onClear: (() -> Void)?
    var itemCount: Int = 0 { didSet { guard oldValue != itemCount else { return }; updateState() } }

    private let titleLabel = NSTextField(labelWithString: "PocketShelf")
    private let badge      = ShelfBadgeView()
    private let clearBtn   = NSButton()

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        titleLabel.font      = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        addSubview(titleLabel)

        badge.isHidden = true
        addSubview(badge)

        let btnCfg = NSImage.SymbolConfiguration(pointSize: 9, weight: .medium)
        clearBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Dismiss")?
            .withSymbolConfiguration(btnCfg)
        clearBtn.bezelStyle = .regularSquare
        clearBtn.isBordered = false
        clearBtn.wantsLayer = true
        clearBtn.layer?.cornerRadius = 9
        clearBtn.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor
        clearBtn.contentTintColor = NSColor.white.withAlphaComponent(0.85)
        clearBtn.target = self
        clearBtn.action = #selector(clearTapped)
        addSubview(clearBtn)
    }

    private func updateState() {
        badge.isHidden = itemCount == 0
        badge.count    = itemCount
        needsLayout    = true
    }

    @objc private func clearTapped() { onClear?() }

    override func layout() {
        super.layout()
        let h = bounds.height
        clearBtn.frame = NSRect(x: bounds.width-18, y: (h-18)/2, width: 18, height: 18)
        let titleW = titleLabel.intrinsicContentSize.width
        let badgeW: CGFloat = itemCount > 0 ? 24 : 0
        let gap: CGFloat    = itemCount > 0 ? 5  : 0
        let totalW = titleW + gap + badgeW
        let titleX = (bounds.width - totalW) / 2
        titleLabel.frame = NSRect(x: titleX, y: (h-16)/2, width: titleW, height: 16)
        if itemCount > 0 {
            badge.frame = NSRect(x: titleX + titleW + gap, y: (h-16)/2, width: badgeW, height: 16)
        }
    }
}

// MARK: - ShelfBadgeView

private final class ShelfBadgeView: NSView {
    var count: Int = 0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let str = "\(count)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: kAccent
        ]
        let ts   = str.size(withAttributes: attrs)
        let pillW = max(ts.width + 8, 16)
        let pill  = CGRect(x: (bounds.width-pillW)/2, y: (bounds.height-14)/2, width: pillW, height: 14)
        NSBezierPath(roundedRect: pill, xRadius: 7, yRadius: 7).fill()
        kAccent.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: pill, xRadius: 7, yRadius: 7).fill()
        str.draw(at: NSPoint(x: (bounds.width-ts.width)/2, y: (bounds.height-ts.height)/2), withAttributes: attrs)
    }
}

// MARK: - ShelfEmptyStateView

private final class ShelfEmptyStateView: NSView {
    private let wellLayer  = CAShapeLayer()
    private let arrowView  = NSImageView()
    private let hintLabel  = NSTextField(labelWithString: "Drop files here")
    private let subLabel   = NSTextField(labelWithString: "Drag again to send them anywhere")

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { fatalError() }

    func setHovering(_ on: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.16)
        wellLayer.strokeColor = on ? kAccent.withAlphaComponent(0.85).cgColor : NSColor.white.withAlphaComponent(0.14).cgColor
        wellLayer.fillColor   = on ? kAccent.withAlphaComponent(0.08).cgColor : nil
        wellLayer.lineDashPattern = on ? [] : [5, 4]
        CATransaction.commit()
        let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        arrowView.image = NSImage(systemSymbolName: on ? "plus" : "arrow.up", accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        arrowView.contentTintColor = on ? kAccent : NSColor.white.withAlphaComponent(0.55)
        hintLabel.textColor = on ? kAccent : NSColor.white.withAlphaComponent(0.85)
    }

    private func setup() {
        wantsLayer = true
        wellLayer.fillColor = nil; wellLayer.strokeColor = NSColor.white.withAlphaComponent(0.14).cgColor
        wellLayer.lineWidth = 1.5; wellLayer.lineDashPattern = [5, 4]; wellLayer.cornerRadius = 12
        layer?.addSublayer(wellLayer)
        let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        arrowView.image = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        arrowView.contentTintColor = NSColor.white.withAlphaComponent(0.55)
        addSubview(arrowView)
        hintLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold); hintLabel.textColor = NSColor.white.withAlphaComponent(0.85); hintLabel.alignment = .center; addSubview(hintLabel)
        subLabel.font = NSFont.systemFont(ofSize: 10.5, weight: .regular); subLabel.textColor = NSColor.white.withAlphaComponent(0.50); subLabel.alignment = .center; addSubview(subLabel)
    }

    override func layout() {
        super.layout()
        let w = bounds.width, h = bounds.height
        let sz: CGFloat = 44, wx = (w-sz)/2, wy = h - sz - 4
        wellLayer.frame = CGRect(x: wx, y: wy, width: sz, height: sz)
        wellLayer.path  = CGPath(roundedRect: wellLayer.bounds, cornerWidth: 12, cornerHeight: 12, transform: nil)
        arrowView.frame = NSRect(x: wx+(sz-18)/2, y: wy+(sz-18)/2, width: 18, height: 18)
        let hy = wy - 8 - 16
        hintLabel.frame = NSRect(x: 0, y: hy,       width: w, height: 16)
        subLabel.frame  = NSRect(x: 0, y: hy-4-13,  width: w, height: 13)
    }
}

// MARK: - ShelfItemView

final class ShelfItemView: NSView, NSDraggingSource {
    // Callbacks set by ShelfView
    var onMouseDown:       ((NSEvent)   -> Void)?
    var onDragOut:         (([ShelfItem], Bool) -> Void)?
    var getSelectedItems:  (() -> [ShelfItem])?

    var isSelected: Bool = false {
        didSet {
            layer?.backgroundColor = isSelected ? kAccent.withAlphaComponent(0.18).cgColor : nil
            layer?.borderColor     = isSelected ? kAccent.withAlphaComponent(0.60).cgColor : NSColor.clear.cgColor
            layer?.borderWidth     = isSelected ? 1 : 0
        }
    }

    let item: ShelfItem
    let thumbView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var pendingDragItems: [ShelfItem] = []

    init(item: ShelfItem) {
        self.item = item
        super.init(frame: .zero)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8

        thumbView.image          = item.thumbnail
        thumbView.imageScaling   = .scaleProportionallyUpOrDown
        thumbView.wantsLayer     = true
        thumbView.layer?.cornerRadius  = kThumbRadius
        thumbView.layer?.masksToBounds = true
        addSubview(thumbView)

        // Update when QL thumbnail finishes loading
        item.onThumbnailUpdated = { [weak self] img in self?.thumbView.image = img }

        label.stringValue   = item.filename
        label.font          = NSFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor     = NSColor.white.withAlphaComponent(0.86)
        label.alignment     = .center
        label.lineBreakMode = .byTruncatingMiddle
        addSubview(label)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isSelected { layer?.backgroundColor = NSColor.white.withAlphaComponent(0.09).cgColor }
    }
    override func mouseExited(with event: NSEvent) {
        if !isSelected { layer?.backgroundColor = nil }
    }

    override func layout() {
        super.layout()
        let thumbX = (bounds.width - kThumbSize) / 2
        thumbView.frame = NSRect(x: thumbX, y: kCaptionH + kTileInnerGap, width: kThumbSize, height: kThumbSize)
        label.frame     = NSRect(x: 0, y: 0, width: bounds.width, height: kCaptionH)
    }

    // Forward mouseDown to ShelfView for selection handling
    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        let itemsToDrag = getSelectedItems?() ?? [item]
        pendingDragItems = itemsToDrag

        var draggingItems: [NSDraggingItem] = []
        for (offset, dragItem) in itemsToDrag.enumerated() {
            let pb = NSPasteboardItem()
            pb.setString(dragItem.url.absoluteString, forType: .fileURL)
            let di = NSDraggingItem(pasteboardWriter: pb)
            let stackOff = CGFloat(offset) * 2
            let frame = NSRect(x: thumbView.frame.minX + stackOff,
                               y: thumbView.frame.minY - stackOff,
                               width: kThumbSize, height: kThumbSize)
            di.setDraggingFrame(frame, contents: dragItem.thumbnail)
            draggingItems.append(di)
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move, .link] : []
    }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        onDragOut?(pendingDragItems.isEmpty ? [item] : pendingDragItems, !operation.isEmpty)
        pendingDragItems.removeAll()
    }
}
