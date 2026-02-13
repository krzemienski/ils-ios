import SwiftUI
import ILSShared

enum SessionExporter {
    /// Generate plain-text export string for a session.
    static func exportText(for session: ChatSession) -> String {
        "Session: \(session.name ?? "Unnamed")\nModel: \(session.model)\nCreated: \(DateFormatters.dateTime.string(from: session.createdAt))\nMessages: \(session.messageCount)"
    }

    /// Present platform-appropriate share UI for a session.
    static func share(_ session: ChatSession) {
        let text = exportText(for: session)

        #if os(iOS)
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
        #else
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(session.name ?? "session").txt"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        #endif
    }
}
