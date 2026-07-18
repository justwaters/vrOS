/// QR scanning is now handled by the Cardboard SDK's built-in scanner.
///
/// Call `cardboardManager.scanQrCode()` to launch the SDK's QR scan view controller,
/// which handles camera permission, QR capture, URL redirect resolution, and
/// saving device parameters to NSUserDefaults.
///
/// The render loop polls `checkAndReloadDeviceParams()` each frame to detect
/// newly saved parameters and reload the lens distortion mesh automatically.
