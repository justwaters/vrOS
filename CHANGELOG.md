# Changelog

All notable changes to vrOS are documented here. Releases are tagged `vX.Y.Z` on `main` and published as GitHub Releases: https://github.com/justwaters/vrOS/releases

## Codename convention

Each major version line ships under one codename, assigned once at the `vX.0.0` release and kept for every `vX.y.z` that follows in that line. When the project ships the next major version, a **new** codename is chosen for that new line — codenames never carry across major versions, and past codenames are never reused.

| Major line | Codename        |
|------------|------------------|
| v1.x.x     | vrOS Solitude    |
| v2.x.x     | TBD — name it at the v2.0.0 release, then add a row here |

When you cut vX.0.0 for a new major version: pick the codename, add a row to this table, and follow the same release process as the entry below.

## [1.0.0] — vrOS Solitude — 2026-08-17

First public release.

### Added
- macOS display capture via `ScreenCaptureKit` at 1920×1080 @ 30fps
- Hardware H.264 encode (macOS, `VideoToolbox`) → decode (iOS) pipeline
- Custom binary wire protocol over USB-forwarded TCP (`localhost:2345` via `iproxy`)
- Metal-based stereo rendering on iOS: side-by-side split, barrel distortion, chromatic aberration correction
- Head tracking and lens distortion via Google's Cardboard SDK (`cardboard-sdk` submodule, pinned at `v1.34.0`)
- Latency and frame-count HUD

### Fixed
- Cardboard head tracking: orientation lock, axis order, and world-lock math corrected for landscape use

### Known limitations
- No audio capture
- No USB hot-plug detection
- No key-frame request / error recovery on dropped frames
- No display selection UI (primary display only)
- No unit tests
