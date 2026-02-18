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

    /// Share text content as a file in Caches/TextExports.
    init(text: String, fileName: String) {
        let data = Data(text.utf8)
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let exportDir = cachesDir.appendingPathComponent("TextExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        var mutableExportDir = exportDir
        var dirValues = URLResourceValues()
        dirValues.isExcludedFromBackup = true
        try? mutableExportDir.setResourceValues(dirValues)
        let fileURL = exportDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
        } catch {
            AppLogger.shared.error("Failed to write export file '\(fileName)': \(error)", category: "export")
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
