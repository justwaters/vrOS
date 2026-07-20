import SwiftUI
import ScreenCaptureKit
import OSLog

private let logger = Logger(subsystem: "com.vros.sender", category: "App")

@main
struct VROSSenderApp: App {
    @StateObject private var streamManager = StreamManager()

    init() {
        checkScreenRecordingPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(streamManager)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(streamManager)
        }
    }

    private func checkScreenRecordingPermission() {
        Task {
            do {
                let content = try await SCShareableContent.current
                if content.displays.isEmpty {
                    logger.warning("No displays available for capture")
                }
            } catch {
                logger.error("Screen recording permission not granted: \(error)")
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var streamManager: StreamManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "visionpro")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("vrOS Sender")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(streamManager.statusText)
                .font(.headline)
                .foregroundStyle(streamManager.isStreaming ? .green : .secondary)

            if streamManager.isStreaming {
                Text("Streaming at \(streamManager.configuration.width)×\(streamManager.configuration.height) @ \(streamManager.configuration.frameRate)fps")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("USB Port: \(streamManager.configuration.usbPort)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Frames sent: \(streamManager.frameCount)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            if streamManager.iproxyState == .notFound {
                VStack(spacing: 12) {
                    Image(systemName: "cable.connector.horizontal")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("iproxy not found")
                        .font(.headline.weight(.medium))
                    Text("libusbmuxd is required to forward USB packets from your Mac to your iOS device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Install libusbmuxd") {
                        Task { await streamManager.installDependencies() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    if streamManager.isInstalling {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(streamManager.installStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            if streamManager.iproxyState == .ready || streamManager.iproxyState == .running {
                Button(streamManager.isStreaming ? "Stop Streaming" : "Start Streaming") {
                    Task {
                        if streamManager.isStreaming {
                            await streamManager.stop()
                        } else {
                            await streamManager.start()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(streamManager.isStarting || streamManager.isStopping)
            }

            if streamManager.isStarting || streamManager.isStopping {
                ProgressView()
                    .controlSize(.small)
            }

            if let error = streamManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(width: 400)
        .onAppear {
            Task { await streamManager.checkIproxy() }
        }
    }
}

enum IproxyState: Equatable {
    case checking
    case notFound
    case ready
    case running
    case failed(String)
}

@MainActor
final class StreamManager: ObservableObject {
    @Published var isStreaming = false
    @Published var isStarting = false
    @Published var isStopping = false
    @Published var frameCount: Int64 = 0
    @Published var lastError: String?
    @Published var statusTextPublished = "Ready"

    @Published var distortionK1: Float = 0.2
    @Published var distortionK2: Float = 2.0
    @Published var deadbandMode: DeadbandMode = .off

    @Published var iproxyState: IproxyState = .checking
    @Published var isInstalling = false
    @Published var installStatus = ""

    let configuration = StreamConfiguration.default1080p30
    private var controller: StreamController?
    private var iproxyProcess: Process?

    private let iproxyPaths = [
        "/opt/homebrew/bin/iproxy",
        "/usr/local/bin/iproxy",
        "/opt/local/bin/iproxy",
        "/usr/bin/iproxy",
    ]

    var statusText: String {
        if isStreaming { return "Streaming" }
        if isStarting { return "Starting..." }
        if isStopping { return "Stopping..." }
        return "Ready"
    }

    func checkIproxy() async {
        iproxyState = .checking
        if findIproxy() != nil {
            iproxyState = .ready
        } else {
            iproxyState = .notFound
        }
    }

    func installDependencies() async {
        isInstalling = true
        lastError = nil

        defer { isInstalling = false }

        if !hasBrew() {
            installStatus = "Installing Homebrew..."
            do {
                try await runInstallScript(
                    "/bin/bash",
                    arguments: ["-c", "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"],
                    label: "Homebrew"
                )
            } catch {
                lastError = "Homebrew installation failed: \(error.localizedDescription)"
                iproxyState = .failed(error.localizedDescription)
                return
            }
        }

        installStatus = "Installing libusbmuxd..."
        do {
            try await runInstallScript(
                "/opt/homebrew/bin/brew",
                arguments: ["install", "libusbmuxd"],
                label: "libusbmuxd"
            )
        } catch {
            lastError = "libusbmuxd installation failed: \(error.localizedDescription)"
            iproxyState = .failed(error.localizedDescription)
            return
        }

        installStatus = "Starting iproxy..."
        guard let path = findIproxy() else {
            lastError = "iproxy still not found after installation. Try restarting the app."
            iproxyState = .failed("iproxy not found after install")
            return
        }

        do {
            try launchIproxy(path: path)
            iproxyState = .running
            installStatus = ""
        } catch {
            lastError = "Failed to launch iproxy: \(error.localizedDescription)"
            iproxyState = .failed(error.localizedDescription)
        }
    }

    func start() async {
        isStarting = true
        lastError = nil

        do {
            if iproxyProcess == nil || !iproxyProcess!.isRunning {
                if let path = findIproxy() {
                    try launchIproxy(path: path)
                } else {
                    throw IproxyError.notFound
                }
            }

            controller = try await StreamController(configuration: configuration)
            await controller?.startStreaming()
            isStreaming = true
            sendDistortion()
            sendDeadband()
            startFrameCounter()
        } catch {
            lastError = error.localizedDescription
            logger.error("Failed to start: \(error)")
        }

        isStarting = false
    }

    func stop() async {
        isStopping = true
        await controller?.stopStreaming()
        controller = nil
        isStreaming = false
        frameCount = 0
        isStopping = false
    }

    func stopEverything() async {
        await stop()
        stopIproxy()
        iproxyState = findIproxy() != nil ? .ready : .notFound
    }

    func sendDistortion() {
        Task { await controller?.sendDistortion(k1: distortionK1, k2: distortionK2) }
    }

    func sendDeadband() {
        Task { await controller?.sendDeadband(mode: deadbandMode) }
    }

    private func findIproxy() -> String? {
        for path in iproxyPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return which("iproxy")
    }

    private func which(_ command: String) -> String? {
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["which", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        } catch {
            return nil
        }
    }

    private func hasBrew() -> Bool {
        which("brew") != nil
    }

    private func launchIproxy(path: String) throws {
        stopIproxy()
        let process = Process()
        process.launchPath = path
        process.arguments = ["2345", "2345"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.iproxyState == .running else { return }
                self.iproxyState = .failed("iproxy terminated unexpectedly")
                self.lastError = "iproxy stopped. Restart the stream to reconnect."
                if self.isStreaming {
                    await self.stop()
                }
            }
        }
        try process.run()
        iproxyProcess = process
    }

    private func stopIproxy() {
        iproxyProcess?.terminate()
        iproxyProcess = nil
    }

    private func runInstallScript(_ path: String, arguments: [String], label: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.launchPath = path
            process.arguments = arguments
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let msg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: IproxyError.installFailed("\(label): \(msg)"))
                }
            }

            // Stream output for progress
            outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if let line = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !line.isEmpty
                {
                    Task { @MainActor in
                        self?.installStatus = line
                    }
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func startFrameCounter() {
        Task {
            while isStreaming {
                try? await Task.sleep(for: .seconds(1))
                if let controller = controller {
                    frameCount = controller.currentFrameCount
                }
            }
        }
    }

}

enum IproxyError: Error, LocalizedError {
    case notFound
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound: return "iproxy not found. Install libusbmuxd via Homebrew."
        case .installFailed(let msg): return msg
        }
    }
}
