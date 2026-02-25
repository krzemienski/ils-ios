import XCTest
import CoreImage
import Foundation

/// Base class for snapshot-based UI tests with pixel-level comparison
///
/// Usage:
///   - First run: set `isRecordingSnapshots = true` to save reference images
///   - Subsequent runs: set `isRecordingSnapshots = false` (default) to compare against references
///
/// Reference images are stored in:
///   ILSApp/ILSAppUITests/SnapshotTests/ReferenceImages/<TestClassName>/<snapshotName>.png
class SnapshotTestBase: XCUITestBase {

    // MARK: - Configuration

    /// Set to true to record new reference images instead of comparing
    var isRecordingSnapshots = false

    /// Maximum allowed normalized pixel difference (0.0–1.0, default 1%)
    var snapshotTolerance: CGFloat = 0.01

    // MARK: - Reference Image Directory

    /// Resolves the ReferenceImages directory relative to this source file
    private func referenceImagesDirectory(sourceFilePath: StaticString = #file) -> URL {
        let sourceFile = URL(fileURLWithPath: "\(sourceFilePath)")
        // SnapshotTestBase.swift lives in SnapshotTests/
        let snapshotTestsDir = sourceFile.deletingLastPathComponent()
        return snapshotTestsDir.appendingPathComponent("ReferenceImages")
    }

    private func referenceImageURL(
        named name: String,
        testClass: String,
        sourceFilePath: StaticString = #file
    ) -> URL {
        referenceImagesDirectory(sourceFilePath: sourceFilePath)
            .appendingPathComponent(testClass)
            .appendingPathComponent(name)
            .appendingPathExtension("png")
    }

    // MARK: - Screenshot Capture

    /// Captures a screenshot of the full screen or a specific element
    func captureSnapshot(of element: XCUIElement? = nil) throws -> UIImage {
        let screenshotData: Data

        if let element = element {
            let screenshot = element.screenshot()
            screenshotData = screenshot.pngRepresentation
        } else {
            let screenshot = XCUIScreen.main.screenshot()
            screenshotData = screenshot.pngRepresentation
        }

        guard let image = UIImage(data: screenshotData) else {
            throw SnapshotError.captureFailure("Failed to decode screenshot PNG data")
        }
        return image
    }

    // MARK: - Reference Image Persistence

    /// Saves an image as the reference for future comparisons
    private func saveReferenceImage(
        _ image: UIImage,
        named name: String,
        testClass: String,
        sourceFilePath: StaticString = #file
    ) throws {
        let url = referenceImageURL(named: name, testClass: testClass, sourceFilePath: sourceFilePath)
        let directory = url.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        guard let pngData = image.pngData() else {
            throw SnapshotError.saveFailure("Failed to generate PNG data for '\(name)'")
        }

        try pngData.write(to: url, options: .atomic)
    }

    /// Loads the reference image for a given snapshot name
    private func loadReferenceImage(
        named name: String,
        testClass: String,
        sourceFilePath: StaticString = #file
    ) throws -> UIImage {
        // First try source-tree path (for local development)
        let fileURL = referenceImageURL(named: name, testClass: testClass, sourceFilePath: sourceFilePath)
        if let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }

        // Fall back to test bundle (for CI / archived builds)
        let bundle = Bundle(for: type(of: self))
        let bundleResourcePath = "ReferenceImages/\(testClass)/\(name)"
        if let bundleURL = bundle.url(forResource: bundleResourcePath, withExtension: "png"),
           let image = UIImage(contentsOfFile: bundleURL.path) {
            return image
        }

        throw SnapshotError.referenceNotFound(name)
    }

    // MARK: - Pixel-Level Comparison

    /// Compares two images using CoreImage difference blend mode
    /// Returns a result containing a match flag and the normalized difference percentage
    func compareImages(
        _ actual: UIImage,
        _ reference: UIImage,
        tolerance: CGFloat
    ) throws -> SnapshotComparisonResult {
        guard let actualCIImage = CIImage(image: actual) else {
            throw SnapshotError.comparisonFailure("Failed to create CIImage from actual screenshot")
        }
        guard let referenceCIImage = CIImage(image: reference) else {
            throw SnapshotError.comparisonFailure("Failed to create CIImage from reference image")
        }

        let actualSize = actualCIImage.extent.size
        let referenceSize = referenceCIImage.extent.size

        guard actualSize == referenceSize else {
            return SnapshotComparisonResult(
                matches: false,
                differencePercentage: 1.0,
                message: "Size mismatch — actual: \(actualSize), reference: \(referenceSize)"
            )
        }

        // Compute per-pixel absolute difference
        guard let differenceFilter = CIFilter(name: "CIDifferenceBlendMode") else {
            throw SnapshotError.comparisonFailure("CIDifferenceBlendMode filter not available")
        }
        differenceFilter.setValue(actualCIImage, forKey: kCIInputImageKey)
        differenceFilter.setValue(referenceCIImage, forKey: kCIInputBackgroundImageKey)

        guard let differenceImage = differenceFilter.outputImage else {
            throw SnapshotError.comparisonFailure("CIDifferenceBlendMode produced no output")
        }

        // Compute average of the difference image
        guard let areaAvgFilter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: differenceImage,
                "inputExtent": CIVector(cgRect: referenceCIImage.extent)
            ]
        ) else {
            throw SnapshotError.comparisonFailure("CIAreaAverage filter not available")
        }

        guard let avgImage = areaAvgFilter.outputImage else {
            throw SnapshotError.comparisonFailure("CIAreaAverage produced no output")
        }

        // Render the 1×1 average pixel
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            avgImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Average R+G+B channels, normalize to 0–1
        let avgDifference = CGFloat(pixel[0] + pixel[1] + pixel[2]) / (255.0 * 3.0)
        let matches = avgDifference <= tolerance
        let diffPercent = String(format: "%.2f", avgDifference * 100)
        let thresholdPercent = String(format: "%.2f", tolerance * 100)

        return SnapshotComparisonResult(
            matches: matches,
            differencePercentage: avgDifference,
            message: matches
                ? "Snapshot matches (diff: \(diffPercent)%)"
                : "Snapshot mismatch — diff: \(diffPercent)%, threshold: \(thresholdPercent)%"
        )
    }

    // MARK: - Primary Assertion

    /// Asserts that the current screen (or element) matches a reference snapshot.
    ///
    /// On first run, set `isRecordingSnapshots = true` to create the reference.
    /// On subsequent runs, the captured image is compared against the stored reference.
    func assertSnapshot(
        named name: String,
        of element: XCUIElement? = nil,
        tolerance: CGFloat? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let effectiveTolerance = tolerance ?? snapshotTolerance
        let testClass = "\(type(of: self))"

        do {
            let actual = try captureSnapshot(of: element)

            if isRecordingSnapshots {
                try saveReferenceImage(actual, named: name, testClass: testClass, sourceFilePath: file)
                // Attach to test results for visibility
                let attachment = XCTAttachment(image: actual)
                attachment.name = "Recorded_\(name)"
                attachment.lifetime = .keepAlways
                add(attachment)
                return
            }

            let reference = try loadReferenceImage(named: name, testClass: testClass, sourceFilePath: file)
            let result = try compareImages(actual, reference, tolerance: effectiveTolerance)

            if !result.matches {
                attachDiffImages(actual: actual, reference: reference, name: name)
            }

            XCTAssertTrue(result.matches, result.message, file: file, line: line)

        } catch SnapshotError.referenceNotFound(let snapshotName) {
            XCTFail(
                "No reference image found for '\(snapshotName)'. "
                + "Set isRecordingSnapshots = true to record a baseline.",
                file: file,
                line: line
            )
        } catch {
            XCTFail("Snapshot assertion failed: \(error.localizedDescription)", file: file, line: line)
        }
    }

    // MARK: - Diff Attachments

    /// Attaches actual and reference images to the test report for debugging failures
    private func attachDiffImages(actual: UIImage, reference: UIImage, name: String) {
        let actualAttachment = XCTAttachment(image: actual)
        actualAttachment.name = "Actual_\(name)"
        actualAttachment.lifetime = .keepAlways
        add(actualAttachment)

        let referenceAttachment = XCTAttachment(image: reference)
        referenceAttachment.name = "Reference_\(name)"
        referenceAttachment.lifetime = .keepAlways
        add(referenceAttachment)
    }
}

// MARK: - Snapshot Comparison Result

struct SnapshotComparisonResult {
    /// Whether the images match within the configured tolerance
    let matches: Bool
    /// Normalized average pixel difference (0.0 = identical, 1.0 = completely different)
    let differencePercentage: CGFloat
    /// Human-readable description of the comparison outcome
    let message: String
}

// MARK: - Snapshot Errors

enum SnapshotError: Error, LocalizedError {
    case captureFailure(String)
    case referenceNotFound(String)
    case saveFailure(String)
    case comparisonFailure(String)

    var errorDescription: String? {
        switch self {
        case .captureFailure(let msg):   return "Capture failure: \(msg)"
        case .referenceNotFound(let name): return "Reference image not found: '\(name)'"
        case .saveFailure(let msg):      return "Save failure: \(msg)"
        case .comparisonFailure(let msg): return "Comparison failure: \(msg)"
        }
    }
}
