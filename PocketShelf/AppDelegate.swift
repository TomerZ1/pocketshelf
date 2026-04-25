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
    private var shakeDetector: ShakeDetector?
    private var shakeOpened = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        shelfPanel = ShelfPanel()
        hotkeyManager = HotkeyManager { [weak self] in self?.toggleShelf() }

        shakeDetector = ShakeDetector()
        shakeDetector?.onShake = { [weak self] in
            guard let panel = self?.shelfPanel, !panel.isVisible else { return }
            panel.showWithSpring()
            self?.shakeOpened = true
        }
        // If the shelf was opened by a shake and nothing was dropped, close it when the drag ends
        shakeDetector?.onDragEnd = { [weak self] in
            guard let self, self.shakeOpened else { return }
            self.shakeOpened = false
            guard let panel = self.shelfPanel, panel.isVisible, panel.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak panel] in
                guard let panel, panel.isVisible, panel.isEmpty else { return }
                panel.hide()
            }
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
        let show  = NSMenuItem(title: "Show / Hide Shelf", action: #selector(toggleShelf), keyEquivalent: "")
        let clear = NSMenuItem(title: "Clear Shelf", action: #selector(clearShelf), keyEquivalent: "")
        let quit  = NSMenuItem(title: "Quit PocketShelf", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        show.target  = self
        clear.target = self
        quit.target  = NSApp     // terminate(_:) lives on NSApplication, not AppDelegate
        let menu = NSMenu()
        menu.addItem(show)
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(quit)
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func toggleShelf() {
        guard let panel = shelfPanel else { return }
        if panel.isVisible {
            panel.hide()
        } else {
            panel.show()
        }
    }

    @objc func clearShelf() {
        shelfPanel?.clearItems()
        shelfPanel?.hide()
    }
}
