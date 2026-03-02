#if os(iOS)
import SwiftUI
import AVFoundation

/// QR code scanner view for capturing backend URLs during onboarding.
///
/// Presents a live camera preview with a scanning overlay consisting of corner-bracket
/// frame markers and an animated horizontal scan line. When a QR code containing a valid
/// URL is detected the `onScanned` closure is called and the sheet dismisses automatically.
/// If the user denies camera access a fallback screen with a deep-link to Settings is shown.
///
/// ## Topics
/// ### Callbacks
/// - ``onScanned`` - Called with the scanned URL string when a valid URL is detected
///
/// ### State
/// - ``scannerCoordinator`` - AVFoundation coordinator bridging camera output to SwiftUI
/// - ``cameraPermission`` - Tracks `AVAuthorizationStatus` for graceful fallback
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: ThemeSnapshot

    let onScanned: (String) -> Void

    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scannerCoordinator: QRScannerCoordinator?
    @State private var scanLineOffset: CGFloat = -120
    @State private var isAnimatingScanLine = false
    @State private var lastScanned: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch cameraPermission {
            case .authorized:
                cameraView
            case .notDetermined:
                requestingPermissionView
            default:
                permissionDeniedView
            }
        }
        .onAppear {
            requestCameraPermissionIfNeeded()
        }
        .accessibilityLabel("QR Code Scanner")
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            // Live camera preview
            QRCameraPreviewView(coordinator: $scannerCoordinator, onScanned: handleScanned)
                .ignoresSafeArea()

            // Dimming overlay outside scan frame
            scanFrameOverlay

            // Controls
            VStack {
                topBar
                Spacer()
                bottomHint
            }
        }
    }

    // MARK: - Scan Frame Overlay

    private var scanFrameOverlay: some View {
        GeometryReader { geo in
            let frameSize: CGFloat = min(geo.size.width, geo.size.height) * 0.65
            let x = (geo.size.width - frameSize) / 2
            let y = (geo.size.height - frameSize) / 2

            ZStack {
                // Dimming mask around scan frame
                Color.black.opacity(0.55)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .frame(width: frameSize, height: frameSize)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .allowsHitTesting(false)

                // Corner brackets
                cornerBrackets(size: frameSize)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Scan line animation
                if isAnimatingScanLine {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0),
                                    Color.cyan.opacity(0.8),
                                    Color.cyan.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: frameSize - 24, height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                        .shadow(color: .cyan.opacity(0.6), radius: 6)
                        .position(
                            x: geo.size.width / 2,
                            y: y + (frameSize / 2) + scanLineOffset
                        )
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                startScanLineAnimation(frameSize: frameSize)
            }
            .onDisappear {
                withAnimation(.linear(duration: 0.0)) {
                    isAnimatingScanLine = false
                }
            }
        }
    }

    private func cornerBrackets(size: CGFloat) -> some View {
        let bracketLength: CGFloat = 28
        let bracketThickness: CGFloat = 3
        let inset: CGFloat = 0

        return ZStack {
            // Top-left
            bracketShape(size: size, inset: inset, bracketLength: bracketLength,
                         thickness: bracketThickness, corner: .topLeft)
            // Top-right
            bracketShape(size: size, inset: inset, bracketLength: bracketLength,
                         thickness: bracketThickness, corner: .topRight)
            // Bottom-left
            bracketShape(size: size, inset: inset, bracketLength: bracketLength,
                         thickness: bracketThickness, corner: .bottomLeft)
            // Bottom-right
            bracketShape(size: size, inset: inset, bracketLength: bracketLength,
                         thickness: bracketThickness, corner: .bottomRight)
        }
    }

    private enum BracketCorner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private func bracketShape(size: CGFloat, inset: CGFloat,
                               bracketLength: CGFloat, thickness: CGFloat,
                               corner: BracketCorner) -> some View {
        let half = size / 2
        let x: CGFloat
        let y: CGFloat
        let rotation: Double

        switch corner {
        case .topLeft:
            x = -half + inset; y = -half + inset; rotation = 0
        case .topRight:
            x = half - inset; y = -half + inset; rotation = 90
        case .bottomRight:
            x = half - inset; y = half - inset; rotation = 180
        case .bottomLeft:
            x = -half + inset; y = half - inset; rotation = 270
        }

        return Path { path in
            path.move(to: CGPoint(x: 0, y: bracketLength))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: bracketLength, y: 0))
        }
        .stroke(Color.cyan, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        .frame(width: bracketLength, height: bracketLength)
        .rotationEffect(.degrees(rotation))
        .offset(x: x, y: y)
        .shadow(color: .cyan.opacity(0.5), radius: 4)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .accessibilityLabel("Cancel QR scan")

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Bottom Hint

    private var bottomHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.7))

            Text("Align the QR code from your\nTunnel Settings screen")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 48)
    }

    // MARK: - Permission Views

    private var requestingPermissionView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.white)
            Text("Requesting camera access…")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 10) {
                Text("Camera Access Required")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Allow camera access in Settings to scan QR codes from your Tunnel Settings screen.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
            .accessibilityLabel("Open Settings to grant camera permission")

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .accessibilityLabel("Cancel")

            Spacer()
        }
    }

    // MARK: - Helpers

    private func requestCameraPermissionIfNeeded() {
        switch cameraPermission {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                }
            }
        case .authorized:
            break
        default:
            break
        }
    }

    private func startScanLineAnimation(frameSize: CGFloat) {
        let halfFrame = frameSize / 2
        scanLineOffset = -halfFrame + 12
        isAnimatingScanLine = true
        withAnimation(
            .linear(duration: 2.2)
            .repeatForever(autoreverses: true)
        ) {
            scanLineOffset = halfFrame - 12
        }
    }

    private func handleScanned(_ urlString: String) {
        guard urlString != lastScanned else { return }
        guard isValidURL(urlString) else { return }
        lastScanned = urlString
        HapticManager.notification(.success)
        onScanned(urlString)
        dismiss()
    }

    private func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return false
        }
        return true
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

/// UIKit bridge providing an `AVCaptureVideoPreviewLayer` backed live camera feed
/// and a metadata output delegate for detecting QR codes.
private struct QRCameraPreviewView: UIViewRepresentable {
    @Binding var coordinator: QRScannerCoordinator?
    let onScanned: (String) -> Void

    func makeCoordinator() -> QRScannerCoordinator {
        QRScannerCoordinator(onScanned: onScanned)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = context.coordinator.session
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            context.coordinator.startSession()
        }

        DispatchQueue.main.async {
            coordinator = context.coordinator
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: QRScannerCoordinator) {
        coordinator.stopSession()
    }
}

// MARK: - Scanner Coordinator

/// AVFoundation coordinator that owns the capture session and routes detected
/// QR code strings back to the SwiftUI layer via the `onScanned` closure.
final class QRScannerCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?
    private let onScanned: @Sendable (String) -> Void
    private var isRunning = false

    init(onScanned: @escaping @Sendable (String) -> Void) {
        self.onScanned = onScanned
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        session.startRunning()
        isRunning = true
    }

    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
        isRunning = false
    }

    // MARK: AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        onScanned(stringValue)
    }
}
#endif
