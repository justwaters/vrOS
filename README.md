# vrOS — macOS to iOS VR Desktop Streaming

Stream your macOS desktop to an iPhone for viewing in a VR headset (Google Cardboard, etc.) over a USB connection.

## Architecture

```
┌──────────────────────────────┐         USB TCP (localhost:2345)           ┌──────────────────────────────┐
│       macOS Sender App       │  ────── H.264 in custom packets ────────▶ │       iOS Receiver App       │
│                              │                                            │                              │
│  ScreenCaptureKit ─► H.264   │                                            │ H.264 decode ─► Metal + VR   │
│  (captures display)   encode │                                            │ lens distortion + SBS render  │
│                              │                                            │                              │
│  StreamController            │                                            │  ReceiverViewModel           │
│    ├─ VideoEncoder (actor)   │                                            │    ├─ USBListener            │
│    ├─ USBClient (TCP)        │                                            │    ├─ VideoDecoder           │
│    └─ SCStream               │                                            │    └─ MetalRenderer          │
└──────────────────────────────┘                                            └──────────────────────────────┘
```

## Data Flow

1. **macOS** captures the primary display via `ScreenCaptureKit` → `CVPixelBuffer`
2. **VideoEncoder** (Swift actor) compresses frames to H.264 Annex B via `VideoToolbox`
3. Encoded frames are wrapped in a custom binary packet (30-byte header + payload)
4. **USBClient** sends packets over TCP to `localhost:2345` (forwarded to iPhone via `iproxy`)
5. **iOS** `USBListener` accepts the connection and parses packets from the TCP stream
6. **VideoDecoder** configures `VTDecompressionSession` from SPS/PPS, decodes H.264 frames
7. Decoded `CVPixelBuffer` is uploaded to a `MTLTexture` via `CVMetalTextureCache`
8. **MetalRenderer** draws the texture onto a full-screen quad with per-eye barrel distortion and chromatic aberration correction (SBS stereo via instanced rendering)

## Key Technologies

| Technology | Purpose |
|---|---|
| **ScreenCaptureKit** | macOS display capture (primary display, configurable resolution/framerate) |
| **VideoToolbox** | Hardware H.264 encode (macOS) and decode (iOS) via GPU/Media Engine |
| **Metal** | GPU rendering with VR lens distortion shaders |
| **Network.framework** | TCP communication over USB tethering |
| **USB Tethering / iproxy** | Mac connects to `localhost:2345`, forwarded to iOS via USB |
| **Swift 6 Concurrency** | `async/await`, `AsyncStream`, `actor` throughout both apps |
| **SwiftUI** | Minimal UI on both sides |

## Requirements

- **macOS 13.0+** (Ventura) for the sender
- **iOS 16.0+** for the receiver
- **Xcode 15.0+** (Swift 6 language mode)
- USB cable connecting Mac to iPhone

## Setup

### 0. Fetch the Cardboard SDK submodule

`cardboard-sdk/` is a git submodule (Google's Cardboard SDK). The iOS Receiver target compiles files directly out of it, so the build will fail with missing-file errors until it's populated:

```bash
git submodule update --init --recursive
```

Run this after cloning, and again after pulling if `cardboard-sdk` shows as changed.

### 1. Generate Xcode projects

```bash
cd vrOS
chmod +x setup_xcode_projects.sh
./setup_xcode_projects.sh
```

### 2. Configure signing

Open each `.xcodeproj` in Xcode and set your development team in Signing & Capabilities.

### 3. Build & Run

Build and run both targets from Xcode, or:

```bash
# macOS Sender
xcodebuild -project macOSSender/vrOSSender.xcodeproj \
  -scheme vrOSSender -destination 'platform=macOS'

# iOS Receiver
xcodebuild -project iOSReceiver/vrOSReceiver.xcodeproj \
  -scheme vrOSReceiver -destination 'platform=iOS,name=Your iPhone'
```

### 4. Connect

1. Plug iPhone into Mac via USB
2. Forward TCP port: `iproxy 2345 2345`
3. Launch the iOS Receiver app first (it listens on port 2345)
4. Launch the macOS Sender app — grant Screen Recording permission when prompted
5. Press **Start Streaming** on the Mac

## Wire Protocol

Custom binary protocol over TCP, port 2345:

### Header (30 bytes, big-endian)

| Offset | Size | Field |
|--------|------|-------|
| 0 | 4 | Magic (`0x55534250` = `USBP`) |
| 4 | 2 | Version |
| 6 | 2 | Packet type |
| 8 | 2 | Flags |
| 10 | 4 | Sequence number |
| 14 | 8 | Timestamp (nanoseconds) |
| 22 | 4 | Payload length |
| 26 | 4 | Checksum |

### Packet Types

| Type | Value | Payload |
|------|-------|---------|
| Config | `0x0001` | SPS + PPS NAL units (Annex B) |
| ConfigAck | `0x0002` | (empty) |
| KeyFrame | `0x0010` | H.264 key frame (Annex B) |
| VideoFrame | `0x0011` | H.264 frame (Annex B) |
| Heartbeat | `0x0100` | (empty) |
| KeyFrameRequest | `0x0101` | (empty) |

## Project Structure

```
vrOS/
├── Shared/                      # Shared protocol & models
│   ├── USBPacket.swift          # Wire protocol packet definition
│   └── USBDevice.swift          # USB device model + IOKit monitoring
├── macOSSender/vrOSSender/
│   ├── App.swift                # SwiftUI entry + StreamManager
│   ├── Controller/
│   │   └── StreamController.swift   # ScreenCaptureKit + encoding pipeline
│   ├── Encoder/
│   │   └── VideoEncoder.swift        # H.264 VideoToolbox encoder (actor)
│   └── Networking/
│       └── USBServer.swift          # TCP client to iOS
├── iOSReceiver/vrOSReceiver/
│   ├── App.swift                # SwiftUI entry
│   ├── ContentView.swift        # UI + ReceiverViewModel pipeline
│   ├── Decoder/
│   │   └── VideoDecoder.swift   # H.264 VideoToolbox decoder
│   ├── Networking/
│   │   └── USBClient.swift      # TCP listener on iOS
│   └── Renderer/
│       ├── MetalRenderer.swift  # Metal rendering with VR distortion
│       └── Shaders.metal        # Vertex/fragment shaders (SBS + CA)
└── setup_xcode_projects.sh      # Xcode project generator
```

## Current State

- ✅ macOS display capture at 1920×1080 @ 30fps
- ✅ H.264 hardware encode → decode pipeline
- ✅ USB TCP transport via iproxy
- ✅ Metal rendering with SBS stereo split
- ✅ Barrel distortion + chromatic aberration correction
- ✅ Latency and frame count HUD
- ⬜ Audio capture
- ⬜ USB hot-plug detection
- ⬜ Key frame request / error recovery
- ⬜ Display selection UI (currently primary display only)
- ⬜ Unit tests

## Releases

vrOS uses one codename per major version (e.g. all `v1.x.x` releases are **vrOS Solitude**); a new major version gets a new codename. See [`CHANGELOG.md`](CHANGELOG.md) for the full convention and version history, and the [Releases page](https://github.com/justwaters/vrOS/releases) for downloads/notes.
