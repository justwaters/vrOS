import SwiftUI
import MetalKit
import OSLog

private let logger = Logger(subsystem: "com.vros.receiver", category: "ContentView")

struct ContentView: View {
    @StateObject private var viewModel = ReceiverViewModel()

    var body: some View {
        ZStack {
            MetalViewRepresentable(renderer: viewModel.renderer)
                .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(viewModel.connectionState == .connected ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(viewModel.connectionStateText)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }

                        if viewModel.connectionState == .connected {
                            Text("\(viewModel.configuration.width)×\(viewModel.configuration.height) @ \(viewModel.configuration.frameRate)fps")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text("Frames: \(viewModel.frameCount)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.8))
                            Text("Packets: \(viewModel.packetCount)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.8))
                            Text("Decoder: \(viewModel.decoderReady ? "Ready" : "Waiting")")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.8))
                            Text("Latency: \(viewModel.estimatedLatency)ms")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(12)
                    .background(.black.opacity(0.6))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()

                Spacer()

                if viewModel.connectionState != .connected {
                    VStack(spacing: 16) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                            .font(.system(size: 64))
                            .foregroundStyle(.white)

                        Text("Connect macOS Sender via USB")
                            .font(.title2)
                            .foregroundStyle(.white)

                        Text("Ensure vrOS Sender is running on Mac")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        Button("Retry Connection") {
                            Task { await viewModel.reconnect() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.black.opacity(0.7))
                    .cornerRadius(20)
                }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            Task { await viewModel.start() }
        }
        .onDisappear {
            Task { await viewModel.stop() }
        }
    }
}

struct MetalViewRepresentable: UIViewRepresentable {
    let renderer: MetalRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = renderer.device
        view.delegate = renderer
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isOpaque = true
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

@MainActor
final class ReceiverViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var frameCount: Int64 = 0
    @Published var estimatedLatency: Int = 0

    let configuration = StreamConfiguration.default1080p30
    let renderer = MetalRenderer()

    private var usbListener: USBListener?
    private var videoDecoder: VideoDecoder?
    private var processingTask: Task<Void, Never>?
    private var lastFrameTime: UInt64 = 0
    @Published var packetCount: Int = 0
    @Published var decoderReady: Bool = false

    var connectionStateText: String {
        switch connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Listening..."
        case .connected: return "Connected"
        case .failed: return "Failed"
        }
    }

    func start() async {
        usbListener = USBListener()
        videoDecoder = VideoDecoder(configuration: .default1080p) { [weak self] frame in
            await self?.handleDecodedFrame(frame)
        }
        videoDecoder?.onDecoderReady = { @MainActor in
            self.decoderReady = true
        }

        processingTask = Task {
            for await state in usbListener!.stateStream {
                await MainActor.run { self.connectionState = state }
            }
        }

        try? await usbListener?.start()

        Task {
            for await packet in usbListener!.packetStream {
                print("📦 Packet received: type=\(packet.header.type) seq=\(packet.header.sequenceNumber) size=\(packet.payload.count)")
                await MainActor.run { self.packetCount &+= 1 }
                await videoDecoder?.processPacket(packet)
            }
        }
    }

    func stop() async {
        processingTask?.cancel()
        await usbListener?.disconnect()
        videoDecoder?.invalidate()
        videoDecoder = nil
        usbListener = nil
    }

    func reconnect() async {
        await stop()
        try? await Task.sleep(for: .seconds(1))
        await start()
    }

    private func handleDecodedFrame(_ frame: VideoDecoder.DecodedFrame) async {
        let now = DispatchTime.now().uptimeNanoseconds
        if lastFrameTime > 0 {
            let latencyMs = Int((now - lastFrameTime) / 1_000_000)
            await MainActor.run { self.estimatedLatency = latencyMs }
        }
        lastFrameTime = now

        await MainActor.run {
            self.frameCount &+= 1
            self.renderer.updateTexture(frame.pixelBuffer)
        }
    }
}

struct StreamConfiguration: Sendable {
    let width: Int
    let height: Int
    let frameRate: Int
    let bitRate: Int

    static let default1080p30 = StreamConfiguration(
        width: 1920,
        height: 1080,
        frameRate: 30,
        bitRate: 15_000_000
    )
}
