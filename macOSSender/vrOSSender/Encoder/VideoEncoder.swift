import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import OSLog

private let logger = Logger(subsystem: "com.vros.sender", category: "VideoEncoder")

actor VideoEncoder {
    public struct Configuration: Sendable {
        public let width: Int
        public let height: Int
        public let frameRate: Int
        public let bitRate: Int
        public let profileLevel: String
        public let keyFrameInterval: Int

        public static let default1080p30 = Configuration(
            width: 1920,
            height: 1080,
            frameRate: 30,
            bitRate: 15_000_000,
            profileLevel: kVTProfileLevel_H264_Baseline_AutoLevel as String,
            keyFrameInterval: 30
        )
    }

    public struct EncodedFrame: Sendable {
        public let data: Data
        public let isKeyFrame: Bool
        public let presentationTimeStamp: CMTime
        public let timestamp: UInt64
        public let sps: Data?
        public let pps: Data?
    }

    private var compressionSession: VTCompressionSession?
    private let configuration: Configuration
    private var outputCallback: (@Sendable (EncodedFrame) async -> Void)?
    private var frameCount: Int64 = 0

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    func setOutputCallback(_ callback: @escaping @Sendable (EncodedFrame) async -> Void) {
        self.outputCallback = callback
    }

    func start() async throws {
        try createCompressionSession()
    }

    private func createCompressionSession() throws {
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(configuration.width),
            height: Int32(configuration.height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: kCFAllocatorDefault,
            outputCallback: compressionOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let compressionSession = session else {
            throw EncodingError.sessionCreationFailed(status)
        }

        self.compressionSession = compressionSession

        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ProfileLevel, value: configuration.profileLevel as CFString)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: configuration.keyFrameInterval as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: configuration.frameRate as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AverageBitRate, value: configuration.bitRate as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_DataRateLimits, value: [configuration.bitRate as CFNumber, 1 as CFNumber] as CFArray)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        VTCompressionSessionPrepareToEncodeFrames(compressionSession)
        logger.info("Encoder session created: \(self.configuration.width)x\(self.configuration.height) @ \(self.configuration.frameRate)fps")
    }

    private let compressionOutputCallback: VTCompressionOutputCallback = { refcon, sourceFrameRefCon, status, infoFlags, sampleBuffer in
        guard status == noErr, let sampleBuffer = sampleBuffer else { return }

        let encoder = Unmanaged<VideoEncoder>.fromOpaque(refcon!).takeUnretainedValue()
        var isKeyFrame = false
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]] {
            isKeyFrame = !(attachments.first?[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)
        }
        let timestamp = UInt64(DispatchTime.now().uptimeNanoseconds)
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        var spsData: Data?
        var ppsData: Data?
        if isKeyFrame, let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            var spsPtr: UnsafePointer<UInt8>?
            var spsSize: Int = 0
            var ppsPtr: UnsafePointer<UInt8>?
            var ppsSize: Int = 0
            let spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDesc, parameterSetIndex: 0,
                parameterSetPointerOut: &spsPtr, parameterSetSizeOut: &spsSize,
                parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil
            )
            let ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDesc, parameterSetIndex: 1,
                parameterSetPointerOut: &ppsPtr, parameterSetSizeOut: &ppsSize,
                parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil
            )
            if spsStatus == noErr, ppsStatus == noErr,
               let spsPtr, let ppsPtr {
                spsData = Data(bytes: spsPtr, count: spsSize)
                ppsData = Data(bytes: ppsPtr, count: ppsSize)
            }
        }

        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)

        guard let dataPointer = dataPointer, length > 0 else { return }

        var annexBData = Data()
        var offset = 0
        let raw = UnsafeMutableRawPointer(dataPointer).assumingMemoryBound(to: UInt8.self)
        while offset < length {
            guard offset + 4 <= length else { break }
            let nalLength = UInt32(raw[offset]) << 24 | UInt32(raw[offset + 1]) << 16 | UInt32(raw[offset + 2]) << 8 | UInt32(raw[offset + 3])
            offset += 4
            guard offset + Int(nalLength) <= length else { break }
            annexBData.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            annexBData.append(raw + offset, count: Int(nalLength))
            offset += Int(nalLength)
        }

        let frame = EncodedFrame(
            data: annexBData,
            isKeyFrame: isKeyFrame,
            presentationTimeStamp: pts,
            timestamp: timestamp,
            sps: spsData,
            pps: ppsData
        )

        Task {
            await encoder.outputCallback?(frame)
        }
    }

    private func convertToAnnexB(_ data: UnsafeMutablePointer<UInt8>, length: Int) -> Data {
        var output = Data()
        var offset = 0

        while offset < length {
            guard offset + 4 <= length else { break }

            let nalLength = UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
            offset += 4

            guard offset + Int(nalLength) <= length else { break }

            output.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            output.append(data + offset, count: Int(nalLength))
            offset += Int(nalLength)
        }

        return output
    }

    func encodeFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async throws {
        guard let session = compressionSession else {
            throw EncodingError.sessionNotReady
        }

        let frameNumber = frameCount
        frameCount &+= 1

        let frameProperties: CFDictionary? = frameNumber == 0 ? [
            kVTEncodeFrameOptionKey_ForceKeyFrame: kCFBooleanTrue
        ] as CFDictionary : nil

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: CMTime(value: 1, timescale: Int32(configuration.frameRate)),
            frameProperties: frameProperties,
            sourceFrameRefcon: UnsafeMutableRawPointer(bitPattern: Int(frameNumber)),
            infoFlagsOut: nil
        )

        if status != noErr {
            throw EncodingError.encodeFailed(status)
        }
    }

    func requestKeyFrame() async {
        guard let session = compressionSession else { return }
        VTSessionSetProperty(session, key: kVTEncodeFrameOptionKey_ForceKeyFrame, value: kCFBooleanTrue)
    }

    func stop() {
        let session = compressionSession
        compressionSession = nil
        if let session = session {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
    }

    public enum EncodingError: Error, Sendable {
        case sessionCreationFailed(OSStatus)
        case sessionNotReady
        case encodeFailed(OSStatus)
        case invalidPixelBuffer
    }
}