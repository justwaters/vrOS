import Foundation
import Metal
import MetalKit
import CoreVideo
import OSLog
import UIKit
import Combine

private let logger = Logger(subsystem: "com.vros.receiver", category: "MetalRenderer")

enum RenderMode: Sendable {
    case vr
    case ar
}

@MainActor
final class MetalRenderer: NSObject, ObservableObject, MTKViewDelegate {
    let device: MTLDevice
    let cardboardManager: CardboardSDKManager
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let simplePipelineState: MTLRenderPipelineState
    private let passthroughPipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let positionBuffer: MTLBuffer
    private let texCoordBuffer: MTLBuffer
    private let arTexCoordBuffer: MTLBuffer
    private let uniformBuffer: MTLBuffer
    private let textureCache: CVMetalTextureCache
    private let arTextureCache: CVMetalTextureCache
    private var currentTexture: MTLTexture?
    private var currentCvTexture: CVMetalTexture?
    private var eyeTextures: [MTLTexture] = []
    private var lastViewportSize = CGSize.zero
    private var calibrated = false
    private var headDebugFrameCounter = 0
    private let vrScreenDistance: Float = 2.0
    private let arAnchorDistance: Float = 0.5
    private let arShowVirtualScreen = true

    /// AR (single-camera passthrough) is opt-in and switchable; VR (today's
    /// fully-immersive Cardboard mode) must keep working unconditionally. Head
    /// tracking is Cardboard's rotation-only tracker in both modes -- AR mode
    /// does not use ARKit: an ARSession takes exclusive ownership of the camera
    /// hardware, so a second AVCaptureSession (needed for the ultra-wide lens,
    /// which ARKit's own supportedVideoFormats doesn't expose on this device)
    /// can never acquire it while an ARSession is running (confirmed on-device:
    /// "ARSession started" immediately followed by "Could not add ultra-wide
    /// camera input"). AR mode therefore only swaps in a plain AVCaptureSession
    /// passthrough image behind the (currently disabled) head-relative screen.
    @Published var mode: RenderMode = .vr {
        didSet {
            guard mode != oldValue else { return }
            switch mode {
            case .vr:
                ultrawideCaptureManager?.stop()
            case .ar:
                if UltrawideCaptureManager.isSupported {
                    if ultrawideCaptureManager == nil {
                        ultrawideCaptureManager = UltrawideCaptureManager()
                    }
                    ultrawideCaptureManager?.start()
                }
            }
            logger.info("Render mode changed to \(String(describing: self.mode), privacy: .public)")
        }
    }
    private var ultrawideCaptureManager: UltrawideCaptureManager?
    private var lumaTexture: MTLTexture?
    private var chromaTexture: MTLTexture?
    private var currentARLumaCvTexture: CVMetalTexture?
    private var currentARChromaCvTexture: CVMetalTexture?

    struct Uniforms {
        var viewportSize: SIMD2<Float>
        var textureSize: SIMD2<Float>
        var headRotation: matrix_float4x4
        var eyeFromHead: matrix_float4x4
        var projectionMatrix: matrix_float4x4
        var screenDistance: Float
    }

    private var uniforms = Uniforms(
        viewportSize: SIMD2<Float>(0, 0),
        textureSize: SIMD2<Float>(1920, 1080),
        headRotation: matrix_identity_float4x4,
        eyeFromHead: matrix_identity_float4x4,
        projectionMatrix: matrix_identity_float4x4,
        screenDistance: 2.0
    )

    override init() {
        let d = MTLCreateSystemDefaultDevice()!
        device = d
        let nativeBounds = UIScreen.main.nativeBounds
        let displayW = Int32(max(nativeBounds.width, nativeBounds.height))
        let displayH = Int32(min(nativeBounds.width, nativeBounds.height))
        cardboardManager = CardboardSDKManager(
            device: d,
            displayWidth: displayW,
            displayHeight: displayH
        )
        cardboardManager.startTracking()

        commandQueue = d.makeCommandQueue()!

        let library = d.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")!
        let fragmentFunction = library.makeFunction(name: "fragmentShader")!

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try! d.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let simplePipelineDescriptor = MTLRenderPipelineDescriptor()
        simplePipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShaderSimple")!
        simplePipelineDescriptor.fragmentFunction = fragmentFunction
        simplePipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        simplePipelineState = try! d.makeRenderPipelineState(descriptor: simplePipelineDescriptor)

        let passthroughPipelineDescriptor = MTLRenderPipelineDescriptor()
        passthroughPipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShaderPassthroughFOV")!
        passthroughPipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShaderPassthrough")!
        passthroughPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        passthroughPipelineState = try! d.makeRenderPipelineState(descriptor: passthroughPipelineDescriptor)

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerState = d.makeSamplerState(descriptor: samplerDescriptor)!

        let quadPositions: [Float] = [
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
             1.0,  1.0
        ]
        positionBuffer = d.makeBuffer(bytes: quadPositions, length: quadPositions.count * MemoryLayout<Float>.stride, options: [])!

        let quadTexCoords: [Float] = [
            0.0, 0.0,
            1.0, 0.0,
            0.0, 1.0,
            1.0, 1.0
        ]
        texCoordBuffer = d.makeBuffer(bytes: quadTexCoords, length: quadTexCoords.count * MemoryLayout<Float>.stride, options: [])!

        // The AR passthrough buffer arrives pre-rotated via
        // AVCaptureConnection.videoOrientation (see UltrawideCaptureManager), so
        // this is a fixed mapping, never rewritten per-frame -- but it is NOT
        // the same as quadTexCoords/texCoordBuffer above: verified on-device
        // that the identity mapping renders the passthrough upside down (V
        // flipped relative to positionBuffer's vertex order), so this flips V
        // to compensate.
        let arQuadTexCoords: [Float] = [
            0.0, 1.0,
            1.0, 1.0,
            0.0, 0.0,
            1.0, 0.0
        ]
        arTexCoordBuffer = d.makeBuffer(bytes: arQuadTexCoords, length: arQuadTexCoords.count * MemoryLayout<Float>.stride, options: [])!

        uniformBuffer = d.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])!

        var cvTextureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, d, nil, &cvTextureCache)
        textureCache = cvTextureCache!

        // Dedicated cache for the AR camera image -- different format/plane-count/cadence
        // than the streamed-video textureCache above, kept isolated on purpose.
        var arCvTextureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, d, nil, &arCvTextureCache)
        arTextureCache = arCvTextureCache!

        super.init()
    }

    deinit {
        cardboardManager.stopTracking()
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        // Head tracking is Cardboard's rotation-only tracker in both modes, so
        // recentering is identical whether the current mode is VR or AR.
        cardboardManager.recenter()
        calibrated = false // Let the next frame compute the flat yaw reference
        logger.info("Recalibrated head tracking reference")
    }

    func updateTexture(_ pixelBuffer: CVPixelBuffer) {
        var cvTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        logger.log("updateTexture: \(width)x\(height) format=\(String(format: "%08x", format))")

        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        if let cvTexture = cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) {
            currentCvTexture = cvTexture
            currentTexture = texture
            uniforms.textureSize = SIMD2<Float>(Float(width), Float(height))
        } else {
            logger.error("updateTexture: failed to create texture from pixel buffer")
        }
    }

    /// Uploads the AR passthrough camera's two-plane YCbCr image as luma/chroma
    /// textures, reusing the same CVMetalTextureCache pattern as updateTexture(_:)
    /// above (planeIndex 0/1 instead of the single-plane BGRA video texture).
    private func updateARCameraTexture(_ pixelBuffer: CVPixelBuffer) {
        let w0 = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let h0 = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        var yTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, arTextureCache, pixelBuffer, nil, .r8Unorm, w0, h0, 0, &yTex
        )

        let w1 = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
        let h1 = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        var cTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, arTextureCache, pixelBuffer, nil, .rg8Unorm, w1, h1, 1, &cTex
        )

        if let yTex, let cTex,
           let lTexture = CVMetalTextureGetTexture(yTex),
           let cTexture = CVMetalTextureGetTexture(cTex) {
            currentARLumaCvTexture = yTex
            currentARChromaCvTexture = cTex
            lumaTexture = lTexture
            chromaTexture = cTexture
            updateARPassthroughTexCoords(textureWidth: w0, textureHeight: h0)
        } else {
            logger.error("updateARCameraTexture: failed to create textures from pixel buffer")
        }
    }

    /// Crops the passthrough image to a centered square: full camera height,
    /// sides trimmed to match. Simpler and more predictable than trying to
    /// match Cardboard's lens FOV by angle (that approach was fragile --
    /// AVCaptureDevice.Format.videoFieldOfView may not reflect the actual
    /// capture crop, Cardboard's per-eye projection can be an asymmetric
    /// frustum that a symmetric-FOV formula only approximates, and clamping
    /// each axis independently could desync the two and reintroduce squeeze).
    private func updateARPassthroughTexCoords(textureWidth: Int, textureHeight: Int) {
        guard textureWidth > 0, textureHeight > 0 else { return }
        let widthScale = min(1, Float(textureHeight) / Float(textureWidth))
        let marginU = (1 - widthScale) / 2
        let u0 = marginU, u1 = 1 - marginU
        let v0: Float = 0, v1: Float = 1

        // Vertex order: bl, br, tl, tr (matches positionBuffer/arQuadTexCoords).
        // V stays flipped (bl/br sample v1, tl/tr sample v0) -- see arTexCoordBuffer's
        // init comment for why the identity (unflipped) mapping renders upside down.
        let coords: [Float] = [
            u0, v1,
            u1, v1,
            u0, v0,
            u1, v0
        ]
        coords.withUnsafeBytes { raw in
            arTexCoordBuffer.contents().copyMemory(from: raw.baseAddress!, byteCount: raw.count)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        lastViewportSize = size
        ensureEyeTextures(size: size)
    }

    private func ensureEyeTextures(size: CGSize) {
        let w = Int(size.width)
        let h = Int(size.height)
        guard w > 0, h > 0 else { return }
        if eyeTextures.count == 2 && eyeTextures[0].width == w && eyeTextures[0].height == h {
            return
        }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: w,
            height: h,
            mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private

        eyeTextures = (0..<2).map { _ in device.makeTexture(descriptor: desc)! }
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        switch mode {
        case .vr:
            renderVRFrame(commandBuffer: commandBuffer, view: view)
        case .ar:
            renderARFrame(commandBuffer: commandBuffer, view: view)
        }
    }

    private func computeHeadRotation() -> matrix_float4x4 {
        cardboardManager.updatePose()

        // headQuat is Cardboard's raw tracker quaternion, used as a
        // world-to-head transform -- matching hellocardboard-ios's own usage
        // in HelloCardboardRenderer::DrawFrame, which applies GetPose()'s
        // quaternion-derived matrix directly as the view matrix with no extra
        // inversion (see also the now-removed transpose() in vertexShader).
        //
        // Negating the imaginary X and Z components (keeping Y and the real
        // part) is mathematically equivalent to conjugating the rotation by a
        // 180°-about-Y rotation (verified algebraically via the Hamilton
        // product: p*q*p^-1 for p=(0,1,0,0) reduces to exactly (-x,y,-z,w)) --
        // i.e. a clean coordinate-handedness fix that holds for ANY rotation,
        // not just pure single-axis ones. Verified on-device this leaves yaw
        // untouched while correcting pitch and roll, which had both come out
        // inverted (tilting right rolled the world-locked screen right instead
        // of left; looking up moved it up instead of down) after removing the
        // old single-Y-negation hack (which only worked for pure yaw because
        // it was compensating for a since-removed erroneous transpose).
        let raw = cardboardManager.headOrientation
        let headQuat = simd_quatf(ix: -raw.imag.x, iy: raw.imag.y, iz: -raw.imag.z, r: raw.real)
        headDebugFrameCounter += 1
        if headDebugFrameCounter % 15 == 0 {
            logger.info("HEADDBG raw=(\(headQuat.imag.x, privacy: .public),\(headQuat.imag.y, privacy: .public),\(headQuat.imag.z, privacy: .public),\(headQuat.real, privacy: .public))")
        }

        if !calibrated {
            // headQuat is world-to-head, so the world-space direction the
            // head is CURRENTLY facing is its inverse applied to the head's
            // local forward (-Z) -- the opposite of what a world-to-head
            // quaternion would give directly.
            let fwd = simd_inverse(headQuat).act(simd_float3(0, 0, -1))

            // Flatten that vector onto the XZ (horizontal) plane
            let flatFwd = simd_float3(fwd.x, 0, fwd.z)

            // Prevent math errors if the user is looking straight up or down
            if simd_length(flatFwd) > 0.001 {
                // Create a quaternion that ONLY rotates the Y-axis (Yaw)
                cardboardManager.referenceOrientation = simd_quaternion(simd_float3(0, 0, -1), simd_normalize(flatFwd))
            } else {
                cardboardManager.referenceOrientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) // Fallback
            }

            calibrated = true
        }

        // referenceOrientation maps canonical forward (0,0,-1) to the
        // world-space direction the head faced at calibration time -- a
        // head-to-world-ish yaw-only rotation. Applying it BEFORE headQuat
        // (world-to-head) removes that initial yaw offset: canonical-forward
        // -> world (reference) -> head (headQuat), which composes to
        // identity-yaw at the moment of calibration by construction.
        let relativeQuat = simd_mul(headQuat, cardboardManager.referenceOrientation)

        // Convert directly to matrix (no cross-product filtering required)
        return matrix_float4x4(relativeQuat)
    }

    private func renderVRFrame(commandBuffer: MTLCommandBuffer, view: MTKView) {
        guard let texture = currentTexture, eyeTextures.count == 2 else { return }

        let headRotation = computeHeadRotation()

        let w = Int(lastViewportSize.width)
        let h = Int(lastViewportSize.height)

        for eye in 0..<2 {
            uniforms.headRotation = headRotation
            uniforms.screenDistance = vrScreenDistance
            uniforms.eyeFromHead = cardboardManager.eyeFromHeadMatrix(forEye: Int32(eye))
            uniforms.projectionMatrix = cardboardManager.projectionMatrix(forEye: Int32(eye), zNear: 0.1, zFar: 100.0)
            uniforms.viewportSize = SIMD2<Float>(Float(w), Float(h))
            withUnsafePointer(to: &uniforms) {
                uniformBuffer.contents().copyMemory(from: $0, byteCount: MemoryLayout<Uniforms>.stride)
            }

            let eyeTex = eyeTextures[eye]
            let passDesc = MTLRenderPassDescriptor()
            passDesc.colorAttachments[0].texture = eyeTex
            passDesc.colorAttachments[0].loadAction = .clear
            passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            passDesc.colorAttachments[0].storeAction = .store

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else {
                continue
            }

            encoder.setRenderPipelineState(pipelineState)
            encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
            encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setFragmentSamplerState(samplerState, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            encoder.endEncoding()
        }

        guard let drawable = view.currentDrawable else { return }
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        cardboardManager.renderEyesToDisplay(
            with: encoder,
            leftTexture: eyeTextures[0],
            rightTexture: eyeTextures[1],
            screenWidth: Int32(w),
            screenHeight: Int32(h)
        )

        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Camera passthrough rendered behind the (currently disabled) floating
    /// screen. AR mode does not use ARKit at all: head tracking is Cardboard's
    /// same rotation-only tracker used in VR mode (computeHeadRotation),
    /// reused here so the screen -- if re-enabled -- stays head-locked exactly
    /// like VR's. Only the passthrough image source differs: a plain
    /// AVCaptureSession (UltrawideCaptureManager) instead of a decoded video
    /// frame.
    private func renderARFrame(commandBuffer: MTLCommandBuffer, view: MTKView) {
        guard let texture = currentTexture, eyeTextures.count == 2 else { return }

        let headRotation = computeHeadRotation()
        let w = Int(lastViewportSize.width)
        let h = Int(lastViewportSize.height)

        var hasARImage = false
        if let pixelBuffer = ultrawideCaptureManager?.latestPixelBuffer {
            updateARCameraTexture(pixelBuffer)
            hasARImage = lumaTexture != nil && chromaTexture != nil
        }

        for eye in 0..<2 {
            uniforms.headRotation = headRotation
            uniforms.screenDistance = arAnchorDistance
            uniforms.eyeFromHead = cardboardManager.eyeFromHeadMatrix(forEye: Int32(eye))
            uniforms.projectionMatrix = cardboardManager.projectionMatrix(forEye: Int32(eye), zNear: 0.1, zFar: 100.0)
            uniforms.viewportSize = SIMD2<Float>(Float(w), Float(h))
            withUnsafePointer(to: &uniforms) {
                uniformBuffer.contents().copyMemory(from: $0, byteCount: MemoryLayout<Uniforms>.stride)
            }

            let eyeTex = eyeTextures[eye]
            let passDesc = MTLRenderPassDescriptor()
            passDesc.colorAttachments[0].texture = eyeTex
            // Passthrough covers every pixel when available, so no clear is needed;
            // fall back to a black clear while the capture session is still warming up.
            passDesc.colorAttachments[0].loadAction = hasARImage ? .dontCare : .clear
            passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            passDesc.colorAttachments[0].storeAction = .store

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc) else {
                continue
            }

            if hasARImage, let lumaTexture, let chromaTexture {
                encoder.setRenderPipelineState(passthroughPipelineState)
                encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
                encoder.setVertexBuffer(arTexCoordBuffer, offset: 0, index: 1)
                encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)
                encoder.setFragmentTexture(lumaTexture, index: 0)
                encoder.setFragmentTexture(chromaTexture, index: 1)
                encoder.setFragmentSamplerState(samplerState, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }

            if arShowVirtualScreen {
                encoder.setRenderPipelineState(pipelineState)
                encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
                encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
                encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)
                encoder.setFragmentTexture(texture, index: 0)
                encoder.setFragmentSamplerState(samplerState, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            encoder.endEncoding()
        }

        guard let drawable = view.currentDrawable else { return }
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        cardboardManager.renderEyesToDisplay(
            with: encoder,
            leftTexture: eyeTextures[0],
            rightTexture: eyeTextures[1],
            screenWidth: Int32(w),
            screenHeight: Int32(h)
        )

        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
