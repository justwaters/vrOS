#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface CardboardManager : NSObject

- (void)start;
- (void)stop;
- (void)recenter;

@property (nonatomic, readonly) simd_quatf orientation;
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;

@end

NS_ASSUME_NONNULL_END
