import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Static utility for compressing image data before upload.
///
/// Accepts raw image bytes (PNG, JPEG, or GIF) and returns a compressed JPEG
/// scaled so the longer side does not exceed `maxLongSide` pixels.
/// Output is always JPEG regardless of input format.
enum ImageCompressionService {

    // MARK: - Constants

    /// Maximum length of the longer dimension in pixels.
    static let maxLongSide: CGFloat = 768

    /// JPEG compression quality (0–1).
    static let jpegQuality: CGFloat = 0.7

    /// Threshold above which a warning is logged before compression.
    private static let largeSizeWarningBytes = 5_000_000 // 5 MB

    // MARK: - Output

    struct CompressedImage {
        let data: Data
        /// Always "image/jpeg".
        let mimeType: String
        let width: Int
        let height: Int
    }

    // MARK: - Public API

    /// Compress image data to a JPEG scaled within `maxLongSide`.
    ///
    /// - Parameters:
    ///   - data: Raw image bytes (PNG, JPEG, or GIF).
    ///   - mimeType: Original MIME type, e.g. "image/png".
    /// - Returns: `CompressedImage` on success, `nil` if the data cannot be decoded.
    static func compress(data: Data, mimeType: String) -> CompressedImage? {
        if data.count > largeSizeWarningBytes {
            AppLogger.shared.warning(
                "ImageCompressionService: input \(data.count) bytes exceeds 5 MB — compressing",
                category: "image"
            )
        }

        #if os(iOS)
        return compressIOS(data: data)
        #elseif os(macOS)
        return compressMac(data: data)
        #endif
    }

    // MARK: - Platform Implementations

    #if os(iOS)
    private static func compressIOS(data: Data) -> CompressedImage? {
        guard let image = UIImage(data: data) else {
            AppLogger.shared.error(
                "ImageCompressionService: failed to decode image data (\(data.count) bytes)",
                category: "image"
            )
            return nil
        }

        let scaled = scaleIOS(image)
        guard let jpegData = scaled.jpegData(compressionQuality: jpegQuality) else {
            AppLogger.shared.error(
                "ImageCompressionService: failed to produce JPEG data",
                category: "image"
            )
            return nil
        }

        let w = Int(scaled.size.width * scaled.scale)
        let h = Int(scaled.size.height * scaled.scale)
        return CompressedImage(data: jpegData, mimeType: "image/jpeg", width: w, height: h)
    }

    private static func scaleIOS(_ image: UIImage) -> UIImage {
        let originalSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        let longSide = max(originalSize.width, originalSize.height)
        guard longSide > maxLongSide else { return image }

        let scale = maxLongSide / longSide
        let newSize = CGSize(
            width: (originalSize.width * scale).rounded(),
            height: (originalSize.height * scale).rounded()
        )

        let renderer = UIGraphicsImageRenderer(
            size: newSize,
            format: UIGraphicsImageRendererFormat.default()
        )
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    #if os(macOS)
    private static func compressMac(data: Data) -> CompressedImage? {
        guard let nsImage = NSImage(data: data) else {
            AppLogger.shared.error(
                "ImageCompressionService: failed to decode image data (\(data.count) bytes)",
                category: "image"
            )
            return nil
        }

        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            AppLogger.shared.error(
                "ImageCompressionService: failed to obtain CGImage from NSImage",
                category: "image"
            )
            return nil
        }

        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        let longSide = max(originalSize.width, originalSize.height)
        let scale = longSide > maxLongSide ? maxLongSide / longSide : 1.0
        let newSize = CGSize(
            width: (originalSize.width * scale).rounded(),
            height: (originalSize.height * scale).rounded()
        )

        guard let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            AppLogger.shared.error(
                "ImageCompressionService: failed to create CGContext for resizing",
                category: "image"
            )
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))

        guard let resizedCGImage = context.makeImage() else {
            AppLogger.shared.error(
                "ImageCompressionService: failed to render resized CGImage",
                category: "image"
            )
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: resizedCGImage)
        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: jpegQuality]
        ) else {
            AppLogger.shared.error(
                "ImageCompressionService: failed to produce JPEG data",
                category: "image"
            )
            return nil
        }

        return CompressedImage(
            data: jpegData,
            mimeType: "image/jpeg",
            width: Int(newSize.width),
            height: Int(newSize.height)
        )
    }
    #endif
}
