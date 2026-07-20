import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreVideo
import VideoToolbox
import OSLog

private let logger = Logger(subsystem: "com.vros.sender", category: "StreamController")

final class StreamController: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private var stream: SCStream!
    private let encoder: VideoEncoder
    private let usbClient: USBClient
    private let captureQueue = DispatchQueue(label: "com.vros.capture", qos: .userInteractive)
    private let encodingQueue = DispatchQueue(label: "com.vros.encoding", qos: .userInteractive)
    private let frameRate: Int
    private var isStreaming = false
    private var frameCount: Int64 = 0
    private var lastFrameTime: CMTime = .zero
    private var configSent = false

    init(configuration: StreamConfiguration) async throws {
        let display = try await StreamController.getPrimaryDisplay()
        let contentFilter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = configuration.width
        streamConfig.height = configuration.height
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: Int32(configuration.frameRate))
        streamConfig.queueDepth = 3
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
        streamConfig.showsCursor = true
        streamConfig.capturesAudio = false

        self.encoder = VideoEncoder(configuration: configuration.encoderConfiguration)
        self.usbClient = USBClient(port: configuration.usbPort)
        self.frameRate = configuration.frameRate

        super.init()

        self.usbClient.onDisconnect = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                logger.error("USB disconnected, stopping stream")
                await self.stopStreaming()
            }
        }

        self.stream = SCStream(filter: contentFilter, configuration: streamConfig, delegate: self)
        try await setupEncoder()
        try await setupStream()
        try await usbClient.start()
    }

    private static func getPrimaryDisplay() async throws -> SCDisplay {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
            throw StreamError.noDisplayFound
        }
        return display
    }

    private func setupEncoder() async throws {
        try await encoder.start()

        await encoder.setOutputCallback { [weak self] frame in
            await self?.handleEncodedFrame(frame)
        }
    }

    private func setupStream() async throws {
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
    }

    private func handleEncodedFrame(_ frame: VideoEncoder.EncodedFrame) async {
        guard isStreaming else {
            logger.warning("handleEncodedFrame: not streaming")
            return
        }

        if !configSent, let sps = frame.sps, let pps = frame.pps {
            logger.info("Sending config SPS: \(sps.count) bytes = \(sps.map { String(format: "%02x", $0) }.joined(separator: " "))")
            logger.info("Sending config PPS: \(pps.count) bytes = \(pps.map { String(format: "%02x", $0) }.joined(separator: " "))")
            let startCode = Data([0x00, 0x00, 0x00, 0x01])
            let configData = startCode + sps + startCode + pps
            let packet = USBPacket(
                type: .config,
                sequenceNumber: 0,
                timestamp: 0,
                payload: configData,
                flags: [.isConfig]
            )
            await usbClient.send(packet.data)
            configSent = true
            logger.info("Sent config packet (SPS: \(sps.count) PPS: \(pps.count))")
        }

        logger.debug("handleEncodedFrame: keyFrame=\(frame.isKeyFrame) size=\(frame.data.count) frameCount=\(self.frameCount)")
        await sendFrame(frame)
    }

    private func sendFrame(_ frame: VideoEncoder.EncodedFrame) async {
        let flags: USBPacket.Header.Flags = frame.isKeyFrame ? [.isKeyFrame, .isEndOfFrame] : [.isEndOfFrame]
        let type: USBPacket.PacketType = frame.isKeyFrame ? .keyFrame : .videoFrame

        let packet = USBPacket(
            type: type,
            sequenceNumber: UInt32(frameCount),
            timestamp: frame.timestamp,
            payload: frame.data,
            flags: flags
        )

        await usbClient.send(packet.data)
        frameCount &+= 1
    }

    func startStreaming() async {
        guard !isStreaming else { return }
        isStreaming = true
        frameCount = 0
        try? await stream.startCapture()
        logger.info("Started streaming")
    }

    func stopStreaming() async {
        guard isStreaming else { return }
        isStreaming = false
        try? await stream.stopCapture()
        await encoder.stop()
        await usbClient.stop()
        logger.info("Stopped streaming")
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error)")
        Task { @MainActor in
            // The caller (StreamManager) should handle cleanup via stopStreaming
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if lastFrameTime.value > 0 {
            let diff = presentationTime - lastFrameTime
            if diff.value > 0 && diff.value < Int64(1_000_000_000 / frameRate) {
                return
            }
        }
        lastFrameTime = presentationTime

        Task { [weak self] in
            guard let self else { return }
            do {
                try await encoder.encodeFrame(pixelBuffer, presentationTime: presentationTime)
            } catch {
                logger.error("Encoding failed: \(error)")
            }
        }
    }

    var currentFrameCount: Int64 {
        frameCount
    }

    func sendDistortion(k1: Float, k2: Float) async {
        guard isStreaming else { return }
        let packet = USBPacket.distortionPacket(k1: k1, k2: k2, sequenceNumber: UInt32(frameCount))
        await usbClient.send(packet.data)
    }

    func sendDeadband(mode: DeadbandMode) async {
        guard isStreaming else { return }
        let packet = USBPacket.deadbandPacket(mode: mode, sequenceNumber: UInt32(frameCount))
        await usbClient.send(packet.data)
    }

    enum StreamError: Error, LocalizedError {
        case noDisplayFound
        case streamSetupFailed(Error)
        case encoderSetupFailed(Error)
        case usbSetupFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noDisplayFound: return "No display found for capture"
            case .streamSetupFailed(let e): return "Stream setup failed: \(e)"
            case .encoderSetupFailed(let e): return "Encoder setup failed: \(e)"
            case .usbSetupFailed(let e): return "USB setup failed: \(e)"
            }
        }
    }
}

struct StreamConfiguration: Sendable {
    let width: Int
    let height: Int
    let frameRate: Int
    let bitRate: Int
    let usbPort: UInt16

    var encoderConfiguration: VideoEncoder.Configuration {
        VideoEncoder.Configuration(
            width: width,
            height: height,
            frameRate: frameRate,
            bitRate: bitRate,
            profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
            keyFrameInterval: 60
        )
    }

    static let default1080p30 = StreamConfiguration(
        width: 1920,
        height: 1080,
        frameRate: 30,
        bitRate: 15_000_000,
        usbPort: 2345
    )

    static let default1440p60 = StreamConfiguration(
        width: 2560,
        height: 1440,
        frameRate: 60,
        bitRate: 30_000_000,
        usbPort: 2345
    )
}
