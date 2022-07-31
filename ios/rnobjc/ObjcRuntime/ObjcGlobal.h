#import <jsi/jsilib.h>
#import <jsi/jsi.h>
#import <React/RCTBridgeModule.h>

@interface ObjcGlobal : NSObject <RCTBridgeModule>

@property (nonatomic, assign) BOOL setBridgeOnMainQueue;

- (void)install:(facebook::jsi::Runtime &)runtime;
- (void)cleanUp:(facebook::jsi::Runtime &)runtime;

@end
