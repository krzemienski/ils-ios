import SwiftUI

#if os(iOS)
/// UIKit-bridged share sheet for exporting content via UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    private let tempURLs: [URL]

    /// Share raw items (URLs, strings, images, etc.)
    init(items: [Any]) {
        self.activityItems = items
        self.tempURLs = items.compactMap { $0 as? URL }.filter {
            $0.path.hasPrefix(FileManager.default.temporaryDirectory.path)
        }
    }

    /// Share text content as a temporary file.
    init(text: String, fileName: String) {
        let data = Data(text.utf8)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        self.activityItems = [tempURL]
        self.tempURLs = [tempURL]
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
/// macOS placeholder for ShareSheet (use NSSavePanel instead).
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
