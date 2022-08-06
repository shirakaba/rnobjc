#import "ObjcRuntime.h"
#import "HostObjectObjc.h"
#import <React/RCTBridge+Private.h>
#import <jsi/jsi.h>

using namespace facebook;

@implementation ObjcRuntime

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

// The installation lifecycle
- (void)setBridge:(RCTBridge *)bridge {
  // Store the bridge so that we can access it later in the `invalidate` method.
  _bridge = bridge;
  
  // Grab the JSI runtime.
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)self.bridge;
  jsi::Runtime *runtime = (jsi::Runtime *)cxxBridge.runtime;
  if (!runtime) {
    return;
  }
  
//  // To break the build with a useless error message:
//  NSLog(@"value as number 2 %f", jsi::Value([NSNumber numberWithDouble:3.1415926]).asNumber());

  // Set global.objc = jsiString.
  runtime->global().setProperty(
    *runtime,
    "objc",
    jsi::Object::createFromHostObject(*runtime, std::make_shared<HostObjectObjc>())
  );
}

// The cleanup lifecycle
- (void)invalidate {
  // Grab the JSI runtime.
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)self.bridge;
  jsi::Runtime *runtime = (jsi::Runtime *)cxxBridge.runtime;
  if (!runtime) {
    return;
  }

  // Overwrite the "objc" property on the global object with `undefined`.
  runtime->global().setProperty(*runtime, "objc", jsi::Value::undefined());
}

@end
