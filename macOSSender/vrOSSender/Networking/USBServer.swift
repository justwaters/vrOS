import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "com.vros.sender", category: "USBClient")

final class USBClient: @unchecked Sendable {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.vros.usb.client", qos: .userInteractive)
    private let port: UInt16
    private var isConnected = false
    var onDisconnect: (@Sendable () -> Void)?

    init(port: UInt16) {
        self.port = port
    }

    func start(retryCount: Int = 5) async throws {
        isConnected = false

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let endpoint = NWEndpoint.hostPort(host: "localhost", port: NWEndpoint.Port(rawValue: port)!)

        var lastError: Error?
        for attempt in 1...retryCount {
            logger.info("Connection attempt \(attempt)/\(retryCount) to localhost:\(self.port)...")
            do {
                try await establishConnection(to: endpoint, using: parameters)
                logger.info("Connected to iOS receiver")
                return
            } catch {
                lastError = error
                logger.warning("Attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt < retryCount {
                    try await Task.sleep(for: .seconds(Double(attempt)))
                }
            }
        }
        throw lastError ?? USBError.connectionFailed
    }

    private func establishConnection(to endpoint: NWEndpoint, using parameters: NWParameters) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let conn = NWConnection(to: endpoint, using: parameters)
            self.connection = conn
            conn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard !isConnected else { return }
                    isConnected = true
                    continuation.resume()
                case .failed(let error):
                    guard !isConnected else {
                        isConnected = false
                        logger.error("USB connection failed during stream: \(error)")
                        onDisconnect?()
                        return
                    }
                    continuation.resume(throwing: error)
                case .cancelled:
                    guard isConnected else { return }
                    isConnected = false
                    logger.info("USB connection cancelled")
                    onDisconnect?()
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

enum USBError: Error, LocalizedError {
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Could not connect to iOS receiver after multiple attempts"
        }
    }
}
