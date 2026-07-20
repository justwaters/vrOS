import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "com.vros.sender", category: "USBClient")

final class USBClient: @unchecked Sendable {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.vros.usb.client", qos: .userInteractive)
    private let port: UInt16
    private var isConnected = false

    init(port: UInt16) {
        self.port = port
    }

    func start() async throws {
        isConnected = false

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let endpoint = NWEndpoint.hostPort(host: "localhost", port: NWEndpoint.Port(rawValue: port)!)

        logger.info("Connecting to iOS on localhost:\(self.port)...")

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let conn = NWConnection(to: endpoint, using: parameters)
            self.connection = conn
            conn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard !self.isConnected else { return }
                    self.isConnected = true
                    logger.info("Connected to iOS receiver")
                    continuation.resume()
                case .failed(let error):
                    guard !self.isConnected else { return }
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    var isReady: Bool {
        isConnected
    }

    func send(_ data: Data) async {
        guard let connection = connection, isConnected else {
            logger.warning("send skipped: connection not ready, data size=\(data.count)")
            return
        }

        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    logger.error("Send failed: \(error)")
                } else {
                    logger.debug("Sent \(data.count) bytes")
                }
                continuation.resume()
            })
        }
    }

    func stop() async {
        connection?.cancel()
        connection = nil
        isConnected = false
        logger.info("USB Client stopped")
    }
}
