import AppKit

final class ShelfItem: NSObject {
    let url: URL
    let icon: NSImage
    let filename: String

    init(url: URL) {
        self.url = url
        self.filename = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        super.init()
    }
}
