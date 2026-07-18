import Foundation
import Metal
import MetalKit
import CoreVideo
import OSLog
import UIKit

private let logger = Logger(subsystem: "com.vros.receiver", category: "MetalRenderer")

@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let cardboardManager: CardboardSDKManager
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let simplePipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let positionBuffer: MTLBuffer
    private let texCoordBuffer: MTLBuffer
    private let uniformBuffer: MTLBuffer
    private let textureCache: CVMetalTextureCache
    private var currentTexture: MTLTexture?
    private var currentCvTexture: CVMetalTexture?
    private var eyeTextures: [MTLTexture] = []
    private var lastViewportSize = CGSize.zero
    private var calibrated = false

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

        uniformBuffer = d.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])!

        var cvTextureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, d, nil, &cvTextureCache)
        textureCache = cvTextureCache!

        super.init()
    }

    deinit {
        cardboardManager.stopTracking()
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        cardboardManager.recenter()
        calibrated = true
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
        cardboardManager.checkAndReloadDeviceParams()

        guard let texture = currentTexture,
              eyeTextures.count == 2,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        cardboardManager.updatePose()
        let headQuat = cardboardManager.headOrientation

        if !calibrated {
            cardboardManager.referenceOrientation = headQuat
            calibrated = true
        }

        let relativeQuat = simd_mul(headQuat, simd_inverse(cardboardManager.referenceOrientation))
        let headRotation = float4x4(relativeQuat)

        let w = Int(lastViewportSize.width)
        let h = Int(lastViewportSize.height)

        for eye in 0..<2 {
            uniforms.headRotation = headRotation
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

            encoder.setRenderPipelineState(simplePipelineState)
            encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
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
}
