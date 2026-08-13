#import "CardboardManager.h"

#include <cstdint>
#include <memory>
#include <time.h>

#include "head_tracker.h"

@interface CardboardManager () {
    std::unique_ptr<cardboard::HeadTracker> _tracker;
    simd_quatf _lastOrientation;
}

@end

@implementation CardboardManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _tracker = std::make_unique<cardboard::HeadTracker>();
        _lastOrientation = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
    }
    return self;
}

- (void)start {
    _tracker->Resume();
}

- (void)stop {
    _tracker->Pause();
}

- (void)recenter {
    _tracker->Recenter();
}

- (simd_quatf)orientation {
    std::array<float, 3> position;
    std::array<float, 4> orientation;

    int64_t timestamp = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
    _tracker->GetPose(timestamp, kLandscapeRight,
                      position, orientation);

    // orientation is (w, x, y, z), simd_quatf is (ix, iy, iz, r) = (x, y, z, w)
    _lastOrientation = simd_quaternion(orientation[1], orientation[2],
                                       orientation[3], orientation[0]);
    return _lastOrientation;
}

- (BOOL)isTracking {
    return _tracker != nullptr;
}

- (void)dealloc {
    _tracker->Pause();
    _tracker.reset();
}

@end
