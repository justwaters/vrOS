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

            if viewModel.connectionState != .connected {
                StandbyView(state: viewModel.connectionState, onRetry: {
                    Task { await viewModel.reconnect() }
                })
            } else {
                ZStack {
                    HUDView(viewModel: viewModel)
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
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

private struct StandbyView: View {
    let state: ConnectionState
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "visionpro")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .opacity(0.9)
                .padding(.bottom, 24)

            Text("vrOS")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(.bottom, 8)

            switch state {
            case .disconnected:
                Text("Connect macOS Sender via USB")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Ensure vrOS Sender is running on your Mac")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 32)
                Button(action: onRetry) {
                    Label("Retry Connection", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

            case .connecting:
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, 16)
                Text("Listening for incoming connection...")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))

            case .failed:
                Text("Connection Failed")
                    .font(.body)
                    .foregroundStyle(.red.opacity(0.9))
                    .padding(.bottom, 4)
                Text("Check that iproxy is running on your Mac")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 32)
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

            default:
                EmptyView()
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(.black.opacity(0.55))
    }
}

private struct HUDView: View {
    @ObservedObject var viewModel: ReceiverViewModel

    var body: some View {
        GeometryReader { geo in
            let halfW = geo.size.width / 2

            HUDCard(viewModel: viewModel)
                .position(x: halfW / 2 + 10, y: 24)

            HUDCard(viewModel: viewModel)
                .position(x: halfW + halfW / 2 + 10, y: 24)
        }
    }
}

private struct HUDCard: View {
    @ObservedObject var viewModel: ReceiverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Connected")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
            }

            Text("\(viewModel.configuration.width)×\(viewModel.configuration.height) @ \(viewModel.configuration.frameRate)fps")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 12) {
                Label("\(viewModel.frameCount)", systemImage: "film")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.6))
                Label("\(viewModel.estimatedLatency)ms", systemImage: "clock")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.6))
                Label(viewModel.decoderReady ? "Ready" : "Waiting", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
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

        let tap = UITapGestureRecognizer(target: renderer, action: #selector(MetalRenderer.handleTap(_:)))
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}
}

@MainActor
final class ReceiverViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = connectionState == .connected
        }
    }
    @Published var frameCount: Int64 = 0
    @Published var estimatedLatency: Int = 0

    let configuration = StreamConfiguration.default1080p30
    let renderer = MetalRenderer()

    private var usbListener: USBListener?
    private var videoDecoder: VideoDecoder?
    private var processingTask: Task<Void, Never>?
    private var lastFrameTime: UInt64 = 0
    private var lastLatencyUpdate: UInt64 = 0
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
        videoDecoder?.onDeadbandUpdate = { @MainActor [weak self] mode in
            self?.renderer.deadbandMode = mode
        }

        processingTask = Task {
            for await state in usbListener!.stateStream {
                await MainActor.run { self.connectionState = state }
            }
        }

        try? await usbListener?.start()

        Task {
            for await packet in usbListener!.packetStream {
                logger.info("Packet received: type=\(packet.header.type.rawValue, privacy: .public) seq=\(packet.header.sequenceNumber, privacy: .public) size=\(packet.payload.count, privacy: .public)")
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
        if lastFrameTime > 0, now - lastLatencyUpdate >= 1_000_000_000 {
            let latencyMs = Int((now - lastFrameTime) / 1_000_000)
            await MainActor.run { self.estimatedLatency = latencyMs }
            lastLatencyUpdate = now
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
