import AVFoundation
import CoreMedia
import OSLog

private let logger = Logger(subsystem: "com.vros.receiver", category: "UltrawideCaptureManager")

/// Runs a plain AVCaptureSession on the rear camera for AR mode's passthrough
/// background image -- no ARKit involved. Earlier this ran alongside an
/// ARSession (for 6DOF world tracking), but iOS gives ARSession exclusive
/// ownership of the camera hardware: a second AVCaptureSession's
/// canAddInput(_:) fails while any ARSession is running (confirmed on-device:
/// "ARSession started" immediately followed by "Could not add ultra-wide
/// camera input" every time). AR mode dropped ARKit world tracking entirely
/// so this session can own the camera outright, which also means the
/// ultra-wide lens (unavailable through ARKit's own supportedVideoFormats on
/// this device) is finally usable. Prefers ultra-wide, falls back to the
/// default wide-angle camera if no ultra-wide lens exists.
@MainActor
final class UltrawideCaptureManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.vros.ultrawide.capture")
    private(set) var latestPixelBuffer: CVPixelBuffer?

    static var isSupported: Bool {
        preferredDevice() != nil
    }

    private static func preferredDevice() -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    /// AR mode square-crops this feed to (full height) x (full height) --
    /// see MetalRenderer.updateARPassthroughTexCoords -- so the useful square
    /// area is bounded by the format's HEIGHT, not its width. A fixed preset
    /// like .hd1920x1080 forces a 16:9 crop before we ever see the buffer,
    /// discarding vertical sensor area a taller (closer to the sensor's native
    /// 4:3-ish shape) format would have kept. Picks the highest-resolution
    /// format among reasonable (>=24fps) ones instead, ranked by height.
    private static func bestSquareFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        device.formats
            .filter { format in
                format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 24 }
            }
            .max { a, b in
                CMVideoFormatDescriptionGetDimensions(a.formatDescription).height
                    < CMVideoFormatDescriptionGetDimensions(b.formatDescription).height
            }
    }

    func start() {
        guard let device = Self.preferredDevice() else {
            logger.error("No rear camera device found")
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .inputPriority

        if let format = Self.bestSquareFormat(for: device) {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            do {
                try device.lockForConfiguration()
                device.activeFormat = format
                device.unlockForConfiguration()
                logger.info("Using camera: \(device.localizedName, privacy: .public) \(dims.width, privacy: .public)x\(dims.height, privacy: .public) hFOV=\(format.videoFieldOfView, privacy: .public)deg")
            } catch {
                logger.error("Could not lock device for configuration: \(String(describing: error), privacy: .public)")
            }
        } else {
            logger.error("No suitable capture format found")
        }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            logger.error("Could not add camera input")
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            logger.error("Could not add camera video data output")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        // Deliver frames pre-rotated to match the app's locked landscape-right
        // interface.
        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .landscapeRight
        }

        session.commitConfiguration()

        queue.async { [session] in
            session.startRunning()
        }
        logger.info("AR passthrough AVCaptureSession started")
    }

    func stop() {
        queue.async { [session] in
            session.stopRunning()
        }
        latestPixelBuffer = nil
        logger.info("AR passthrough AVCaptureSession stopped")
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        Task { @MainActor in
            self.latestPixelBuffer = pixelBuffer
        }
    }
}
