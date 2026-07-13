import SwiftUI
import ScreenCaptureKit
import OSLog

private let logger = Logger(subsystem: "com.vros.sender", category: "App")

@main
struct VROSSenderApp: App {
    init() {
        checkScreenRecordingPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
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
    @StateObject private var streamManager = StreamManager()

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
    }
}

@MainActor
final class StreamManager: ObservableObject {
    @Published var isStreaming = false
    @Published var isStarting = false
    @Published var isStopping = false
    @Published var frameCount: Int64 = 0
    @Published var lastError: String?
    @Published var statusTextPublished = "Ready"

    let configuration = StreamConfiguration.default1080p30
    private var controller: StreamController?

    var statusText: String {
        if isStreaming { return "Streaming" }
        if isStarting { return "Starting..." }
        if isStopping { return "Stopping..." }
        return "Ready"
    }

    func start() async {
        isStarting = true
        lastError = nil

        do {
            controller = try await StreamController(configuration: configuration)
            await controller?.startStreaming()
            isStreaming = true
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
