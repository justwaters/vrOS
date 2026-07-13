import Foundation
import CoreVideo

extension CVPixelBuffer: @unchecked @retroactive Sendable {}

public struct USBPacket: Sendable {
    public let header: Header
    public let payload: Data

    public init(type: PacketType, sequenceNumber: UInt32, timestamp: UInt64, payload: Data, flags: Header.Flags = []) {
        self.header = Header(
            magic: 0x55534250,
            version: 1,
            type: type,
            flags: flags,
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            payloadLength: UInt32(payload.count),
            checksum: 0
        )
        self.payload = payload
    }

    private init(header: Header, payload: Data) {
        self.header = header
        self.payload = payload
    }

    public var data: Data {
        var data = Data()
        data.reserveCapacity(30 + payload.count)

        data.append(contentsOf: withUnsafeBytes(of: header.magic.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: header.version.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: header.type.rawValue.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: header.flags.rawValue.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: header.sequenceNumber.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: header.timestamp.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: header.payloadLength.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: header.checksum.bigEndian) { Data($0) })
        data.append(payload)
        return data
    }

    public struct Header: Sendable {
        public let magic: UInt32
        public let version: UInt16
        public let type: PacketType
        public let flags: Flags
        public let sequenceNumber: UInt32
        public let timestamp: UInt64
        public let payloadLength: UInt32
        public let checksum: UInt32

        public struct Flags: OptionSet, Sendable {
            public let rawValue: UInt16
            public init(rawValue: UInt16) { self.rawValue = rawValue }

            public static let isKeyFrame = Flags(rawValue: 1 << 0)
            public static let isEndOfFrame = Flags(rawValue: 1 << 1)
            public static let isConfig = Flags(rawValue: 1 << 2)
            public static let isHeartbeat = Flags(rawValue: 1 << 3)
        }
    }

    public enum PacketType: UInt16, Sendable {
        case config = 0x0001
        case configAck = 0x0002
        case keyFrame = 0x0010
        case videoFrame = 0x0011
        case heartbeat = 0x0100
        case keyFrameRequest = 0x0101
    }

    public static func parse(_ data: Data) -> USBPacket? {
        guard data.count >= 30 else { return nil }

        let bytes = data.withUnsafeBytes { Array($0) }
        
        let magic = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
        guard magic == 0x55534250 else { return nil }

        let version = UInt16(bytes[4]) << 8 | UInt16(bytes[5])
        let typeRaw = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
        let flagsRaw = UInt16(bytes[8]) << 8 | UInt16(bytes[9])
        let sequenceNumber = UInt32(bytes[10]) << 24 | UInt32(bytes[11]) << 16 | UInt32(bytes[12]) << 8 | UInt32(bytes[13])
        let timestamp = UInt64(bytes[14]) << 56 | UInt64(bytes[15]) << 48 | UInt64(bytes[16]) << 40 | UInt64(bytes[17]) << 32 |
                        UInt64(bytes[18]) << 24 | UInt64(bytes[19]) << 16 | UInt64(bytes[20]) << 8 | UInt64(bytes[21])
        let payloadLength = UInt32(bytes[22]) << 24 | UInt32(bytes[23]) << 16 | UInt32(bytes[24]) << 8 | UInt32(bytes[25])
        
        guard data.count >= 30 + Int(payloadLength) else { return nil }
        let payload = data[30..<30 + Int(payloadLength)]

        guard let type = PacketType(rawValue: typeRaw) else { return nil }
        let flags = Header.Flags(rawValue: flagsRaw)

        let header = Header(
            magic: magic,
            version: version,
            type: type,
            flags: flags,
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            payloadLength: payloadLength,
            checksum: 0
        )

        return USBPacket(header: header, payload: Data(payload))
    }
}
