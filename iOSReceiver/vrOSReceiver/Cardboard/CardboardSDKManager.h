#import <Foundation/Foundation.h>
#import <simd/simd.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface CardboardSDKManager : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device
                  displayWidth:(int)displayWidth
                 displayHeight:(int)displayHeight;

// Head tracking
- (void)startTracking;
- (void)stopTracking;

// Sets referenceOrientation to the current headOrientation, making the current
// gaze direction the new "forward" for the world-fixed display.
- (void)recenter;

@property (nonatomic, readonly) simd_quatf headOrientation;
@property (nonatomic, readonly) simd_float3 headPosition;

// The orientation used as the "forward" reference. Set at startup and on recenter.
// headOrientation is a world-to-head transform; referenceOrientation is the
// head-to-world-ish yaw-only rotation computed by MetalRenderer.computeHeadRotation
// (flattened from headOrientation's inverse at calibration time), so the renderer
// composes: headRotation = headOrientation * referenceOrientation.
@property (nonatomic) simd_quatf referenceOrientation;

// Per-eye rendering info
- (simd_float4x4)projectionMatrixForEye:(int)eye zNear:(float)zNear zFar:(float)zFar;
- (simd_float4x4)eyeFromHeadMatrixForEye:(int)eye;

// Must be called each frame before accessing headOrientation/headPosition.
- (void)updatePose;

// Replaces device params with data from a QR code scan.
// The data should be protobuf-encoded Cardboard DeviceParams.
// Call this to switch from default V1 params to scanned viewer params.
- (void)reloadWithEncodedDeviceParams:(NSData*)data;

// Composites left/right eye textures to display with barrel distortion.
// Assumes encoder is already created on the current drawable.
- (void)renderEyesToDisplayWithCommandEncoder:(id<MTLRenderCommandEncoder>)encoder
                                  leftTexture:(id<MTLTexture>)leftTexture
                                 rightTexture:(id<MTLTexture>)rightTexture
                                  screenWidth:(int)screenWidth
                                 screenHeight:(int)screenHeight;

@property (nonatomic, readonly, getter=isReady) BOOL ready;

@end

NS_ASSUME_NONNULL_END
