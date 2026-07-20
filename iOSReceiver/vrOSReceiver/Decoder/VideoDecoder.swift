import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import OSLog

private let logger = Logger(subsystem: "com.vros.receiver", category: "VideoDecoder")

final class VideoDecoder: @unchecked Sendable {
    struct Configuration: Sendable {
        let width: Int
        let height: Int
        let frameRate: Int

        static let default1080p = Configuration(width: 1920, height: 1080, frameRate: 30)
    }

    struct DecodedFrame: Sendable {
        let pixelBuffer: CVPixelBuffer
        let presentationTime: CMTime
    }

    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private let configuration: Configuration
    private var spsData: Data?
    private var ppsData: Data?
    private var frameCallback: (@Sendable (DecodedFrame) async -> Void)?
    var onDecoderReady: (@Sendable () async -> Void)?

    private let decodingQueue = DispatchQueue(label: "com.vros.decoding", qos: .userInteractive)
    private var pendingNALs: [Data] = []
    private var frameCount: Int64 = 0

    init(configuration: Configuration, frameCallback: @escaping @Sendable (DecodedFrame) async -> Void) {
        self.configuration = configuration
        self.frameCallback = frameCallback
    }

    func setFrameCallback(_ callback: @escaping @Sendable (DecodedFrame) async -> Void) {
        self.frameCallback = callback
    }

    func processPacket(_ packet: USBPacket) async {
        switch packet.header.type {
        case .config:
            await handleConfigPacket(packet.payload)
        case .keyFrame, .videoFrame:
            await handleVideoPacket(packet)
        default:
            break
        }
    }

    private func handleConfigPacket(_ data: Data) async {
        logger.info("Config packet received: \(data.count) bytes. First 16: \(data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
        var offset = 0
        while offset + 5 <= data.count {
            if data[offset] == 0x00 && data[offset+1] == 0x00 && data[offset+2] == 0x00 && data[offset+3] == 0x01 {
                let nalType = data[offset+4] & 0x1F
                let nalStart = offset + 4
                let nalEnd: Int
                if let nextStart = data[nalStart...].firstRange(of: Data([0x00, 0x00, 0x00, 0x01])) {
                    nalEnd = nextStart.lowerBound
                } else {
                    nalEnd = data.count
                }
                let nalLength = nalEnd - nalStart
                logger.info("Config NAL: type=\(nalType) length=\(nalLength) offset=\(offset)")
                if nalType == 7 {
                    spsData = data[offset+4..<offset+4+nalLength]
                    logger.info("Stored SPS: \(self.spsData!.map { String(format: "%02x", $0) }.joined(separator: " "))")
                } else if nalType == 8 {
                    ppsData = data[offset+4..<offset+4+nalLength]
                    logger.info("Stored PPS: \(self.ppsData!.map { String(format: "%02x", $0) }.joined(separator: " "))")
                }
                offset = nalEnd
            } else {
                offset += 1
            }
        }

        if let sps = spsData, let pps = ppsData {
            logger.info("Calling configureDecoder with SPS=\(sps.count) PPS=\(pps.count)")
            do {
                try await configureDecoder(sps: sps, pps: pps)
            } catch {
                logger.error("configureDecoder failed: \(error)")
            }
        } else {
            logger.warning("Missing SPS or PPS after parsing config packet")
        }
    }

    private func handleVideoPacket(_ packet: USBPacket) async {
        let isKeyFrame = packet.header.flags.contains(.isKeyFrame)
        if isKeyFrame {
            if decompressionSession == nil {
                await extractSPSPPS(from: packet.payload)
            }
            pendingNALs.removeAll()
        }
        pendingNALs.append(packet.payload)

        if packet.header.flags.contains(.isEndOfFrame) {
            await decodeFrame(isKeyFrame: isKeyFrame, timestamp: packet.header.timestamp)
            pendingNALs.removeAll()
        }
    }

    private func extractSPSPPS(from data: Data) async {
        logger.info("Attempting self-config from payload size: \(data.count). First 16 bytes: \(data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " "))")
        var offset = 0
        while offset + 5 <= data.count {
            if data[offset] == 0x00 && data[offset+1] == 0x00 && data[offset+2] == 0x00 && data[offset+3] == 0x01 {
                let nalType = data[offset+4] & 0x1F
                logger.debug("Found NAL unit at offset \(offset), type: \(nalType)")
                let nalStart = offset + 4
                let nalEnd: Int
                if let nextStart = data[nalStart...].firstRange(of: Data([0x00, 0x00, 0x00, 0x01])) {
                    nalEnd = nextStart.lowerBound
                } else {
                    nalEnd = data.count
                }
                let nalLength = nalEnd - nalStart
                if nalType == 7 {
                    logger.info("Extracted SPS (length: \(nalLength))")
                    spsData = data[offset+4..<offset+4+nalLength]
                } else if nalType == 8 {
                    logger.info("Extracted PPS (length: \(nalLength))")
                    ppsData = data[offset+4..<offset+4+nalLength]
                }
                offset = nalEnd
            } else {
                offset += 1
            }
        }

        if let sps = self.spsData, let pps = self.ppsData {
            logger.info("Both SPS and PPS found, calling configureDecoder...")
            do {
                try await configureDecoder(sps: sps, pps: pps)
                logger.info("Decoder self-configured successfully")
            } catch {
                logger.error("Self-configuration failed: \(error)")
            }
        } else {
            logger.warning("Missing parameter sets: SPS=\(self.spsData != nil), PPS=\(self.ppsData != nil)")
        }
    }

    private func configureDecoder(sps: Data, pps: Data) async throws {
        let parameterSets: [Data] = [sps, pps]
        var parameterSetPtrs = parameterSets.map { $0.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) } }
        var parameterSetSizes = parameterSets.map { $0.count }

        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
            allocator: kCFAllocatorDefault,
            parameterSetCount: 2,
            parameterSetPointers: &parameterSetPtrs,
            parameterSetSizes: &parameterSetSizes,
            nalUnitHeaderLength: 4,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDescription = formatDescription else {
            throw DecoderError.formatDescriptionCreationFailed(status)
        }

        var session: VTDecompressionSession?
        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decompressionOutputCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let status2 = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey: [:]
            ] as CFDictionary,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )

        guard status2 == noErr, let decompressionSession = session else {
            throw DecoderError.sessionCreationFailed(status2)
        }

        self.decompressionSession = decompressionSession
        logger.info("Video decoder configured successfully")
        await onDecoderReady?()
    }

    private let decompressionOutputCallback: VTDecompressionOutputCallback = { refcon, sourceFrameRefCon, status, infoFlags, imageBuffer, presentationTimeStamp, presentationDuration in
        if status != noErr {
            logger.error("Decompression callback error: \(status)")
            return
        }
        guard let imageBuffer = imageBuffer else {
            logger.error("Decompression callback: nil imageBuffer")
            return
        }

        let decoder = Unmanaged<VideoDecoder>.fromOpaque(refcon!).takeUnretainedValue()
        logger.info("Decompression callback fired: pts=\(presentationTimeStamp.value)")

        Task {
            await decoder.handleDecodedFrame(imageBuffer, presentationTime: presentationTimeStamp)
        }
    }

    private func handleDecodedFrame(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async {
        let frame = DecodedFrame(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
        await frameCallback?(frame)
    }

    private func decodeFrame(isKeyFrame: Bool, timestamp: UInt64) async {
        guard let session = decompressionSession,
              let formatDescription = formatDescription,
              !pendingNALs.isEmpty else { return }

        let avccData = convertToAVCC(pendingNALs)
        logger.info("Decoding frame: \(avccData.count) bytes (AVCC), isKeyFrame=\(isKeyFrame), nals=\(self.pendingNALs.count)")
        guard let sampleBuffer = createSampleBuffer(from: avccData, formatDescription: formatDescription, timestamp: timestamp) else {
            logger.error("Failed to create sample buffer")
            return
        }

        let flags: VTDecodeFrameFlags = isKeyFrame ? .init(rawValue: 1 << 0) : []
        var infoFlags = VTDecodeInfoFlags()

        let status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: flags,
            frameRefcon: UnsafeMutableRawPointer(bitPattern: Int(frameCount)),
            infoFlagsOut: &infoFlags
        )

        if status != noErr {
            logger.error("Decode failed: \(status)")
        }

        frameCount &+= 1
    }

    private func convertToAVCC(_ nals: [Data]) -> Data {
        var result = Data()
        var totalNALs = 0
        for nal in nals {
            var offset = 0
            while offset < nal.count {
                guard offset + 4 <= nal.count else {
                    logger.warning("convertToAVCC: truncated start code at offset \(offset)")
                    break
                }
                if nal[offset] == 0x00 && nal[offset+1] == 0x00 && nal[offset+2] == 0x00 && nal[offset+3] == 0x01 {
                    offset += 4
                    let nalStart = offset
                    let nalType = nalStart < nal.count ? Int(nal[nalStart] & 0x1F) : -1
                    while offset < nal.count {
                        if offset + 4 <= nal.count,
                           nal[offset] == 0x00 && nal[offset+1] == 0x00 && nal[offset+2] == 0x00 && nal[offset+3] == 0x01 {
                            break
                        }
                        offset += 1
                    }
                    let nalLength = offset - nalStart
                    var lengthBE = UInt32(nalLength).bigEndian
                    withUnsafeBytes(of: &lengthBE) { result.append(contentsOf: $0) }
                    result.append(nal[nalStart..<offset])
                    totalNALs += 1
                    if totalNALs <= 3 {
                        logger.info("convertToAVCC: NAL type=\(nalType) length=\(nalLength)")
                    }
                } else {
                    logger.warning("convertToAVCC: no start code at offset \(offset), bytes: \(nal.dropFirst(offset).prefix(8).map { String(format: "%02x", $0) }.joined(separator: " "))")
                    break
                }
            }
        }
        logger.info("convertToAVCC: \(totalNALs) NALs, \(result.count) bytes total")
        return result
    }

    private func createSampleBuffer(from data: Data, formatDescription: CMFormatDescription, timestamp: UInt64) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var blockBuffer: CMBlockBuffer?

        let nsData = data as NSData
        var customBlockSource = CMBlockBufferCustomBlockSource(
            version: 0,
            AllocateBlock: nil,
            FreeBlock: { refCon, _, _ in
                Unmanaged<NSData>.fromOpaque(refCon!).release()
            },
            refCon: Unmanaged.passRetained(nsData).toOpaque()
        )

        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: UnsafeMutableRawPointer(mutating: nsData.bytes),
            blockLength: nsData.count,
            blockAllocator: kCFAllocatorNull,
            customBlockSource: &customBlockSource,
            offsetToData: 0,
            dataLength: nsData.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, let buffer = blockBuffer else { return nil }

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(configuration.frameRate)),
            presentationTimeStamp: CMTime(value: Int64(timestamp), timescale: 1_000_000_000),
            decodeTimeStamp: .invalid
        )

        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: buffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 1,
            sampleSizeArray: [nsData.count],
            sampleBufferOut: &sampleBuffer
        )

        return sampleBuffer
    }

    func flush() async {
        guard let session = decompressionSession else { return }
        VTDecompressionSessionWaitForAsynchronousFrames(session)
    }

    func invalidate() {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
        spsData = nil
        ppsData = nil
    }

    enum DecoderError: Error, LocalizedError {
        case formatDescriptionCreationFailed(OSStatus)
        case sessionCreationFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .formatDescriptionCreationFailed(let s): return "Format description creation failed: \(s)"
            case .sessionCreationFailed(let s): return "Session creation failed: \(s)"
            }
        }
    }
}
