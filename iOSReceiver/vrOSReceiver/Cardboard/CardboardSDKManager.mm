#import "CardboardSDKManager.h"

#include <memory>
#include <array>

#include "include/cardboard.h"
#include "head_tracker.h"
#include "lens_distortion.h"
#include "distortion_renderer.h"
#include "qrcode/cardboard_v1/cardboard_v1.h"

@interface CardboardSDKManager () {
    std::unique_ptr<cardboard::HeadTracker> _tracker;
    cardboard::LensDistortion* _lensDistortion;
    cardboard::DistortionRenderer* _renderer;
    simd_quatf _lastOrientation;
    simd_float3 _lastPosition;
    simd_quatf _referenceOrientation;
    int _displayWidth;
    int _displayHeight;
    BOOL _ready;
}
@end

@implementation CardboardSDKManager

@synthesize referenceOrientation = _referenceOrientation;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  displayWidth:(int)displayWidth
                 displayHeight:(int)displayHeight {
    self = [super init];
    if (self) {
        _displayWidth = displayWidth;
        _displayHeight = displayHeight;
        _lastOrientation = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
        _lastPosition = simd_make_float3(0, 0, 0);
        _referenceOrientation = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);

        std::vector<uint8_t> device_params =
            cardboard::qrcode::getCardboardV1DeviceParams();

        _lensDistortion = new cardboard::LensDistortion(
            device_params.data(), (int)device_params.size(),
            displayWidth, displayHeight);

        _tracker = std::make_unique<cardboard::HeadTracker>();

        CardboardMetalDistortionRendererConfig config = {0};
        config.mtl_device = (uint64_t)(__bridge void*)device;
        config.color_attachment_pixel_format = MTLPixelFormatBGRA8Unorm;
        config.depth_attachment_pixel_format = MTLPixelFormatInvalid;
        config.stencil_attachment_pixel_format = MTLPixelFormatInvalid;

        CardboardDistortionRenderer* cRenderer =
            CardboardMetalDistortionRenderer_create(&config);

        if (cRenderer) {
            _renderer = reinterpret_cast<cardboard::DistortionRenderer*>(cRenderer);

            CardboardMesh leftMesh = _lensDistortion->GetDistortionMesh(kLeft);
            CardboardMesh rightMesh = _lensDistortion->GetDistortionMesh(kRight);

            _renderer->SetMesh(&leftMesh, kLeft);
            _renderer->SetMesh(&rightMesh, kRight);
            _ready = YES;
        }
    }
    return self;
}

- (void)dealloc {
    delete _renderer;
    delete _lensDistortion;
}

- (void)startTracking {
    _tracker->Resume();
}

- (void)stopTracking {
    _tracker->Pause();
}

- (void)recenter {
    _referenceOrientation = _lastOrientation;
}

- (simd_quatf)headOrientation {
    return _lastOrientation;
}

- (simd_float3)headPosition {
    return _lastPosition;
}

- (simd_float4x4)projectionMatrixForEye:(int)eye zNear:(float)zNear zFar:(float)zFar {
    if (!_lensDistortion) return matrix_identity_float4x4;
    float matrix[16];
    _lensDistortion->GetEyeProjectionMatrix(
        static_cast<CardboardEye>(eye), zNear, zFar, matrix);
    return [self simdFromRowMajor:matrix];
}

- (simd_float4x4)eyeFromHeadMatrixForEye:(int)eye {
    if (!_lensDistortion) return matrix_identity_float4x4;
    float matrix[16];
    _lensDistortion->GetEyeFromHeadMatrix(
        static_cast<CardboardEye>(eye), matrix);
    return [self simdFromRowMajor:matrix];
}

- (void)reloadWithEncodedDeviceParams:(NSData*)data {
    if (!data || data.length == 0) { NSLog(@"QR: nil/empty data"); return; }
    if (!_renderer) { NSLog(@"QR: no renderer"); return; }

    NSLog(@"QR: creating LensDistortion with %lu bytes", (unsigned long)data.length);
    auto* newLens = new cardboard::LensDistortion(
        (const uint8_t*)data.bytes, (int)data.length,
        _displayWidth, _displayHeight);

    CardboardMesh leftMesh = newLens->GetDistortionMesh(kLeft);
    CardboardMesh rightMesh = newLens->GetDistortionMesh(kRight);
    _renderer->SetMesh(&leftMesh, kLeft);
    _renderer->SetMesh(&rightMesh, kRight);

    delete _lensDistortion;
    _lensDistortion = newLens;
    _ready = YES;
    NSLog(@"QR: lens distortion reloaded successfully");
}

- (void)renderEyesToDisplayWithCommandEncoder:(id<MTLRenderCommandEncoder>)encoder
                                  leftTexture:(id<MTLTexture>)leftTexture
                                 rightTexture:(id<MTLTexture>)rightTexture
                                  screenWidth:(int)screenWidth
                                 screenHeight:(int)screenHeight {
    if (!_ready || !_renderer) return;

    CardboardMetalDistortionRendererTargetConfig target;
    target.render_command_encoder = (int64_t)(__bridge void*)encoder;
    target.screen_width = screenWidth;
    target.screen_height = screenHeight;

    CardboardEyeTextureDescription leftDesc;
    leftDesc.texture = (uint64_t)(__bridge void*)leftTexture;
    leftDesc.left_u = 0.0f;
    leftDesc.right_u = 1.0f;
    leftDesc.top_v = 0.0f;
    leftDesc.bottom_v = 1.0f;

    CardboardEyeTextureDescription rightDesc;
    rightDesc.texture = (uint64_t)(__bridge void*)rightTexture;
    rightDesc.left_u = 0.0f;
    rightDesc.right_u = 1.0f;
    rightDesc.top_v = 0.0f;
    rightDesc.bottom_v = 1.0f;

    _renderer->RenderEyeToDisplay(
        reinterpret_cast<uint64_t>(&target),
        0, 0, screenWidth, screenHeight,
        &leftDesc, &rightDesc);
}

- (void)updatePose {
    if (!_tracker) return;
    std::array<float, 3> position;
    std::array<float, 4> orientation;

    int64_t timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    // The interface orientation is locked to UIInterfaceOrientationLandscapeRight
    // (see Info.plist), but Cardboard's viewport-orientation enum is inverted
    // relative to iOS's naming — Google's own hellocardboard-ios sample locks to
    // LandscapeRight and passes kLandscapeLeft here (see HelloCardboardRenderer.mm).
    _tracker->GetPose(timestamp, kLandscapeLeft, position, orientation);

    _lastPosition = simd_make_float3(position[0], position[1], position[2]);
    // Cardboard's Rotation::QuaternionType stores components as (x, y, z, w)
    // (see head_tracker.cc's reference quaternions, e.g. a 90 degree Z rotation
    // is QuaternionType(0, 0, 0.7071, 0.7071)), matching simd_quaternion's
    // (ix, iy, iz, r) parameter order directly -- no reordering needed.
    _lastOrientation = simd_quaternion(orientation[0], orientation[1],
                                       orientation[2], orientation[3]);
}

#pragma mark - Private

- (simd_float4x4)simdFromRowMajor:(const float*)matrix {
    simd_float4 cols[4];
    for (int i = 0; i < 4; i++) {
        cols[i] = simd_make_float4(matrix[i*4 + 0], matrix[i*4 + 1],
                                   matrix[i*4 + 2], matrix[i*4 + 3]);
    }
    return simd_matrix(cols[0], cols[1], cols[2], cols[3]);
}

@end
