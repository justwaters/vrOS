import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "com.vros.receiver", category: "USBListener")

final class USBListener: @unchecked Sendable {
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.vros.usb.listener", qos: .userInteractive)
    private var buffer = Data()

    let stateStream: AsyncStream<ConnectionState>
    private let stateContinuation: AsyncStream<ConnectionState>.Continuation

    let packetStream: AsyncStream<USBPacket>
    private let packetContinuation: AsyncStream<USBPacket>.Continuation

    init() {
        (stateStream, stateContinuation) = AsyncStream.makeStream()
        (packetStream, packetContinuation) = AsyncStream.makeStream()
    }

    func start() async throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true

        listener = try NWListener(using: parameters, on: 2345)

        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: queue)
        updateState(.connecting)
        logger.info("Listening on port 2345")
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("Listener ready")
        case .failed(let error):
            logger.error("Listener failed: \(error)")
            updateState(.disconnected)
        case .cancelled:
            logger.info("Listener cancelled")
            updateState(.disconnected)
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        if self.connection != nil {
            connection.cancel()
            return
        }

        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state)
        }
        connection.start(queue: queue)
        updateState(.connected)
        logger.info("Mac connected via USB")
        startReceiving()
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            logger.info("Connection ready")
        case .failed(let error):
            logger.error("Connection failed: \(error)")
            connection = nil
            updateState(.disconnected)
        case .cancelled:
            logger.info("Connection cancelled")
            connection = nil
            updateState(.disconnected)
        default:
            break
        }
    }

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.processBuffer(data)
            }


            if isComplete {
                self.handleConnectionLost()
                return
            }

            if let error = error {
                logger.error("Receive error: \(error)")
                self.handleConnectionLost()
                return
            }

            self.startReceiving()
        }
    }

    private func processBuffer(_ newData: Data) {
        self.buffer.append(newData)
        logger.debug("Buffer size after append: \(self.buffer.count)")

        while self.buffer.count >= 30 {
            let b = self.buffer.withUnsafeBytes { Array($0) }
            let magic = UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3])
            
            guard magic == 0x55534250 else {
                logger.warning("Bad magic, removing first byte")
                self.buffer.removeFirst()
                continue
            }

            let pl0 = UInt32(b[22]) << 24
            let pl1 = UInt32(b[23]) << 16
            let pl2 = UInt32(b[24]) << 8
            let pl3 = UInt32(b[25])
            let payloadLength = pl0 | pl1 | pl2 | pl3
            
            let totalLength = 30 + Int(payloadLength)
            logger.debug("Parsing packet: payloadLength=\(payloadLength) totalLength=\(totalLength) self.buffer.count=\(self.buffer.count)")

            if self.buffer.count >= totalLength {
                let packetData = self.buffer.prefix(totalLength)
                self.buffer.removeFirst(totalLength)

                if let packet = USBPacket.parse(Data(packetData)) {
                    logger.debug("Parsed packet type=\(String(describing: packet.header.type)) seq=\(packet.header.sequenceNumber)")
                    packetContinuation.yield(packet)
                } else {
                    logger.warning("Failed to parse packet")
                }
            } else {
                break
            }
        }
    }

    private func handleConnectionLost() {
        connection?.cancel()
        connection = nil
        updateState(.disconnected)
    }

    func disconnect() async {
        connection?.cancel()
        listener?.cancel()
        connection = nil
        listener = nil
        updateState(.disconnected)
    }

    private func updateState(_ state: ConnectionState) {
        stateContinuation.yield(state)
    }
}

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case failed(Error)

    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected), (.connecting, .connecting), (.connected, .connected), (.failed, .failed):
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Listening..."
        case .connected: return "Connected"
        case .failed: return "Failed"
        }
    }
}
