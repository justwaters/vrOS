# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

vrOS streams a macOS desktop to an iPhone for viewing in a Cardboard-style VR headset, over a USB-forwarded TCP connection. Two independent Xcode apps talk a custom binary protocol:

- **macOSSender** (`macOSSender/vrOSSender/`) — captures the display with `ScreenCaptureKit`, encodes H.264 via `VideoToolbox`, sends it over TCP.
- **iOSReceiver** (`iOSReceiver/vrOSReceiver/`) — receives the TCP stream, decodes H.264, renders stereo output with Metal + Google's Cardboard SDK (head tracking, lens distortion).
- **Shared/USBPacket.swift** — the wire protocol packet struct, duplicated into both targets (not a shared framework/package — each `.xcodeproj` compiles its own copy of the file at `Shared/USBPacket.swift`).

Full architecture, data flow, and the wire protocol (30-byte header, packet types) are documented in `README.md` — read it first for protocol details; this file focuses on what the README doesn't cover.

## Build

There are no shared Xcode schemes committed to the repo (`xcschememanagement.plist` and `xcuserdata` are gitignored), so `xcodebuild -scheme ...` will fail with "scheme not found" until the project has been opened once in Xcode (which autogenerates the scheme). If building headlessly before that, use `-target` instead of `-scheme`:

```bash
# macOS Sender
xcodebuild -project macOSSender/vrOSSender.xcodeproj -target vrOSSender -destination 'platform=macOS'

# iOS Receiver (device build — Cardboard SDK sources are iOS/objc++, not simulator-tested)
xcodebuild -project iOSReceiver/vrOSReceiver.xcodeproj -target vrOSReceiver -destination 'platform=iOS,name=Your iPhone'
```

Both targets require Swift 6 language mode and a development team set in Signing & Capabilities before building for a device.

There is no test target in either project and no lint config — don't invent test/lint commands.

### Running end-to-end

1. `iproxy 2345 2345` to forward the USB TCP port from iPhone to Mac.
2. Launch the iOS Receiver first — it's the TCP listener (`USBClient.swift`), the Mac is the TCP client (`USBServer.swift`, despite the name).
3. Launch the macOS Sender, grant Screen Recording permission, press Start Streaming.

## Xcode project files are hand-maintained — do not regenerate

`setup_xcode_projects.sh` (and the `create_macos_project.py` / `create_ios_project.py` it writes) predates the current project structure: it emits a minimal `project.pbxproj` listing only the original handful of source files, with no Cardboard SDK references, no `Cardboard/` group, no `SettingsView.swift`, no header/library search paths. Running it now would **overwrite both `.pbxproj` files and silently drop the entire Cardboard integration** (head tracking, distortion rendering — see git history: "Cardboard SDK integration"). Treat the script as historical/stale. Add new files to the existing `.xcodeproj` via Xcode (or careful direct `.pbxproj` edits), never by rerunning the generator.

## Cardboard SDK integration (iOSReceiver)

`cardboard-sdk/` at the repo root is Google's Cardboard SDK, vendored as source (not a prebuilt framework or CocoaPod, despite the `Podfile` inside `cardboard-sdk/` — that Podfile belongs to the upstream project's own sample apps, not to vrOSReceiver). The iOS Receiver target compiles a hand-picked set of Cardboard `.cc`/`.mm` files directly (see `PBXFileReference` entries pointing at `../cardboard-sdk/sdk/...` in `iOSReceiver/vrOSReceiver.xcodeproj/project.pbxproj`) — sensor fusion, head tracker, lens/distortion math, matrix utils, and the iOS-specific sensor + Metal distortion renderer files. `HEADER_SEARCH_PATHS` adds `vrOSReceiver/Cardboard`, `../cardboard-sdk/sdk/include`, and `../cardboard-sdk/sdk`.

The Swift-facing surface is `iOSReceiver/vrOSReceiver/Cardboard/CardboardSDKManager.{h,mm}`, bridged into Swift via `vrOSReceiver-Bridging-Header.h`. It owns head tracking (`headOrientation`/`headPosition`, `recenter`), per-eye projection/view matrices, and compositing left/right eye textures to the display with barrel distortion (`renderEyesToDisplayWithCommandEncoder:...`). `MetalRenderer.swift` renders each eye to an offscreen texture and hands both to `CardboardSDKManager` for final distortion + compositing — it does not do the distortion math itself.

QR-code viewer-profile scanning (`reloadWithEncodedDeviceParams:`) was implemented and then removed (commit "Remove QR code scanner and all AVFoundation dependencies") — the API is still present on `CardboardSDKManager` but nothing in the app calls it; the app runs on default V1 viewer params only.

## Protocol/model changes touch both targets

`Shared/USBPacket.swift` is not referenced by a shared build target — it's compiled independently into both `macOSSender` and `iOSReceiver`. If you change the packet format, header layout, or packet type enum, edit `Shared/USBPacket.swift` and verify both `.pbxproj` files still reference the single copy (they should — check `PBXFileReference`/`PBXBuildFile` entries for `USBPacket.swift` in each project) rather than a stale per-project copy.
