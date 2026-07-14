import Foundation
import Metal
import MetalKit
import CoreVideo
import OSLog

private let logger = Logger(subsystem: "com.vros.receiver", category: "MetalRenderer")

final class MetalRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let positionBuffer: MTLBuffer
    private let texCoordBuffer: MTLBuffer
    private let uniformBuffer: MTLBuffer
    private let textureCache: CVMetalTextureCache
    private var currentTexture: MTLTexture?

    struct Uniforms {
        var viewportSize: SIMD2<Float>
        var textureSize: SIMD2<Float>
        var distortionK1: Float
        var distortionK2: Float
        var eyeSeparation: Float
        var verticalScale: Float
        var eyeRoundness: Float
        var caRed: Float
        var caBlue: Float
    }

    private var uniforms = Uniforms(
        viewportSize: SIMD2<Float>(0, 0),
        textureSize: SIMD2<Float>(1920, 1080),
        distortionK1: 0.2,
        distortionK2: 2.0,
        eyeSeparation: 0.85,
        verticalScale: 0.75,
        eyeRoundness: 0.35,
        caRed: -0.002,
        caBlue: 0.002
    )

    override init() {
        let d = MTLCreateSystemDefaultDevice()!
        device = d
        commandQueue = d.makeCommandQueue()!

        let library = d.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")!
        let fragmentFunction = library.makeFunction(name: "fragmentShader")!

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        pipelineState = try! d.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerState = d.makeSamplerState(descriptor: samplerDescriptor)!

        let positions: [Float] = [
            -1.0, -1.0,
             1.0, -1.0,
            -1.0,  1.0,
             1.0,  1.0
        ]
        positionBuffer = d.makeBuffer(bytes: positions, length: positions.count * MemoryLayout<Float>.stride, options: [])!

        let texCoords: [Float] = [
            0.0, 1.0,
            1.0, 1.0,
            0.0, 0.0,
            1.0, 0.0
        ]
        texCoordBuffer = d.makeBuffer(bytes: texCoords, length: texCoords.count * MemoryLayout<Float>.stride, options: [])!

        uniformBuffer = d.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [])!

        var tc: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, d, nil, &tc)
        textureCache = tc!

        super.init()
    }

    func updateTexture(_ pixelBuffer: CVPixelBuffer) {
        var cvTexture: CVMetalTexture?
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

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
            currentTexture = texture
            uniforms.textureSize = SIMD2<Float>(Float(width), Float(height))
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.viewportSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let texture = currentTexture,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        uniforms.viewportSize = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(positionBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
        encoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 2)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func updateDistortion(k1: Float, k2: Float) {
        uniforms.distortionK1 = k1
        uniforms.distortionK2 = k2
    }
}
