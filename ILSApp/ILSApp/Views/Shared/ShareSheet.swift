import SwiftUI

#if os(iOS)
/// UIKit-bridged share sheet for exporting content via UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    /// Share raw items (URLs, strings, images, etc.)
    init(items: [Any]) {
        self.activityItems = items
    }

    /// Share text content as a temporary file.
    init(text: String, fileName: String) {
        let data = Data(text.utf8)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        self.activityItems = [tempURL]
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
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
