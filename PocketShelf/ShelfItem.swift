import AppKit
import QuickLookThumbnailing

final class ShelfItem: NSObject {
    let url: URL
    let filename: String
    private(set) var thumbnail: NSImage
    var onThumbnailUpdated: ((NSImage) -> Void)?

    init(url: URL) {
        self.url      = url
        self.filename = url.lastPathComponent
        // Show the workspace icon immediately while the real thumbnail loads
        self.thumbnail = NSWorkspace.shared.icon(forFile: url.path)
        super.init()
        loadThumbnail()
    }

    private func loadThumbnail() {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 104, height: 104),   // 2× for Retina
            scale: 2.0,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let self, let rep else { return }
            DispatchQueue.main.async {
                self.thumbnail = rep.nsImage
                self.onThumbnailUpdated?(rep.nsImage)
            }
        }
    }
}
