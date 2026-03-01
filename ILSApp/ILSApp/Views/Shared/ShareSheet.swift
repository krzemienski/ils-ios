import SwiftUI

#if os(iOS)
/// UIKit-bridged share sheet for exporting content via `UIActivityViewController`.
///
/// Supports two initialisation paths: raw `[Any]` items (URLs, images, strings) or
/// text content that is written to a `Caches/ShareExports/` file before presenting.
/// Temporary export files are deleted automatically in the `completionWithItemsHandler`
/// after the user finishes or cancels the share action.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    private let tempURLs: [URL]

    /// Share raw items (URLs, strings, images, etc.)
    init(items: [Any]) {
        self.activityItems = items
        let tempPath = FileManager.default.temporaryDirectory.path
        self.tempURLs = items.compactMap { $0 as? URL }.filter {
            $0.path.hasPrefix(tempPath) || $0.path.contains("ShareExports")
        }
    }

    /// Share text content as a file in Caches (survives backgrounding, cleaned up after share).
    init(text: String, fileName: String) {
        let data = Data(text.utf8)
        guard let baseCachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            self.activityItems = [text]
            self.tempURLs = []
            return
        }
        let cachesDir = baseCachesDir.appendingPathComponent("ShareExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        let fileURL = cachesDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
        } catch {
            AppLogger.shared.error("ShareSheet file write failed: \(error.localizedDescription)", category: "share")
        }
        self.activityItems = [fileURL]
        self.tempURLs = [fileURL]
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        let urlsToClean = tempURLs
        controller.completionWithItemsHandler = { _, _, _, _ in
            for url in urlsToClean {
                try? FileManager.default.removeItem(at: url)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
/// macOS stub for `ShareSheet` — use `NSSavePanel` directly on macOS instead.
///
/// Accepts the same initialisers as the iOS version so call sites compile on both
/// platforms, but renders `EmptyView` and performs no sharing action.
struct ShareSheet: View {
    let activityItems: [Any]

    init(items: [Any]) {
        self.activityItems = items
    }

    init(text: String, fileName: String) {
        self.activityItems = [text]
    }

    var body: some View {
        EmptyView()
    }
}
#endif
