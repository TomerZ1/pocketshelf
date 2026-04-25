import AppKit

@main
struct PocketShelfApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var shelfPanel: ShelfPanel?
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        shelfPanel = ShelfPanel()
        hotkeyManager = HotkeyManager { [weak self] in
            self?.toggleShelf()
        }
        setupMenuBarItem()
    }

    private func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "PocketShelf")
        button.action = #selector(menuBarClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func menuBarClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleShelf()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide Shelf", action: #selector(toggleShelf), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear Shelf", action: #selector(clearShelf), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PocketShelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func toggleShelf() {
        guard let panel = shelfPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.showNearCursor()
        }
    }

    @objc func clearShelf() {
        shelfPanel?.clearItems()
    }
}
