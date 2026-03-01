import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import ILSShared

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Bottom sheet for selecting chat attachments from various sources.
///
/// Presents a list of attachment options:
/// - Camera (iOS only) — captures a photo via `UIImagePickerController`
/// - Photo Library — `PhotosPicker` allowing up to 5 images
/// - Files — `fileImporter` accepting images, PDFs, and plain text
/// - Paste from Clipboard — reads image data from the system pasteboard
///
/// Each selected item is compressed via `ImageCompressionService` and delivered
/// through the `onAttach` callback as `[MessageAttachment]`.
struct AttachmentPickerSheet: View {

    /// Called with the resulting attachments once the user selects a source and items are processed.
    let onAttach: ([MessageAttachment]) -> Void
    /// Called when the sheet should dismiss.
    let onDismiss: () -> Void

    // MARK: - State

    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false

    @Environment(\.theme) private var theme: ThemeSnapshot

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                #if os(iOS)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                }
                #endif

                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                }

                Button {
                    showFileImporter = true
                } label: {
                    Label("Files", systemImage: "folder")
                }

                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "clipboard")
                }
            }
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium])
        // MARK: - Photo Library picker
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoPickerItems,
            maxSelectionCount: 5,
            matching: .images
        )
        .onChange(of: photoPickerItems) { _, items in
            processPhotoPickerItems(items)
        }
        // MARK: - File importer
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .pdf, .plainText],
            allowsMultipleSelection: true
        ) { result in
            processFileImporterResult(result)
        }
        #if os(iOS)
        // MARK: - Camera
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                processCameraImage(image)
            }
        }
        #endif
    }

    // MARK: - Photo Library

    private func processPhotoPickerItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var attachments: [MessageAttachment] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let mimeType = item.supportedContentTypes.first.flatMap { mimeFromUTType($0) } ?? "image/jpeg"
                if let attachment = makeAttachment(from: data, mimeType: mimeType, filename: nil) {
                    attachments.append(attachment)
                }
            }
            await MainActor.run {
                if !attachments.isEmpty {
                    onAttach(attachments)
                    onDismiss()
                }
                photoPickerItems = []
            }
        }
    }

    // MARK: - File Importer

    private func processFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            AppLogger.shared.error("AttachmentPickerSheet: file importer error: \(error)", category: "attachment")
        case .success(let urls):
            Task {
                var attachments: [MessageAttachment] = []
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let filename = url.lastPathComponent
                    let mimeType = mimeFromUTType(UTType(filenameExtension: url.pathExtension) ?? .data) ?? "application/octet-stream"

                    guard let data = try? Data(contentsOf: url) else { continue }

                    if mimeType.hasPrefix("image/") {
                        if let attachment = makeAttachment(from: data, mimeType: mimeType, filename: filename) {
                            attachments.append(attachment)
                        }
                    } else {
                        // Non-image files (PDF, text): base64-encode raw bytes without compression
                        let base64 = data.base64EncodedString()
                        attachments.append(MessageAttachment(
                            mimeType: mimeType,
                            filename: filename,
                            data: base64
                        ))
                    }
                }
                await MainActor.run {
                    if !attachments.isEmpty {
                        onAttach(attachments)
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Clipboard

    private func pasteFromClipboard() {
        #if os(iOS)
        guard let image = UIPasteboard.general.image,
              let data = image.jpegData(compressionQuality: 1.0) else {
            AppLogger.shared.info("AttachmentPickerSheet: clipboard has no image", category: "attachment")
            return
        }
        if let attachment = makeAttachment(from: data, mimeType: "image/jpeg", filename: nil) {
            onAttach([attachment])
            onDismiss()
        }
        #elseif os(macOS)
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .jpeg, properties: [:]) else {
            AppLogger.shared.info("AttachmentPickerSheet: clipboard has no image", category: "attachment")
            return
        }
        if let attachment = makeAttachment(from: data, mimeType: "image/jpeg", filename: nil) {
            onAttach([attachment])
            onDismiss()
        }
        #endif
    }

    // MARK: - Camera Image (iOS)

    #if os(iOS)
    private func processCameraImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 1.0) else { return }
        if let attachment = makeAttachment(from: data, mimeType: "image/jpeg", filename: nil) {
            onAttach([attachment])
        }
    }
    #endif

    // MARK: - Helpers

    /// Compress image data and return a `MessageAttachment`, or nil on failure.
    private func makeAttachment(from data: Data, mimeType: String, filename: String?) -> MessageAttachment? {
        guard let compressed = ImageCompressionService.compress(data: data, mimeType: mimeType) else {
            AppLogger.shared.error("AttachmentPickerSheet: compression failed for \(mimeType)", category: "attachment")
            return nil
        }
        return MessageAttachment(
            mimeType: compressed.mimeType,
            filename: filename,
            data: compressed.data.base64EncodedString(),
            width: compressed.width,
            height: compressed.height
        )
    }

    private func mimeFromUTType(_ type: UTType) -> String? {
        if type.conforms(to: .jpeg) { return "image/jpeg" }
        if type.conforms(to: .png)  { return "image/png" }
        if type.conforms(to: .gif)  { return "image/gif" }
        if type.conforms(to: .pdf)  { return "application/pdf" }
        if type.conforms(to: .plainText) { return "text/plain" }
        if type.conforms(to: .image)    { return "image/jpeg" }
        return type.preferredMIMEType
    }
}

// MARK: - Camera Picker (iOS)

#if os(iOS)
/// `UIViewControllerRepresentable` wrapper for `UIImagePickerController` in `.camera` mode.
private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif
