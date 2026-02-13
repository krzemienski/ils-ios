import SwiftUI

#if os(iOS)
/// UIKit-bridged share sheet for exporting text content as a file.
struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    let fileName: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let data = Data(text.utf8)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        let controller = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
/// macOS placeholder for ShareSheet (use NSSavePanel instead)
struct ShareSheet: View {
    let text: String
    let fileName: String
    
    var body: some View {
        EmptyView()
    }
}
#endif
