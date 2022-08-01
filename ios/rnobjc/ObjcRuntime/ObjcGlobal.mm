#import "ObjcGlobal.h"
#import <React/RCTBridge+Private.h>
#import <jsi/jsi.h>

using namespace facebook;

@implementation ObjcGlobal

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

  // Create a JSI string from a C string.
  jsi::String jsiString = jsi::String::createFromUtf8(*runtime, "A C string!");

  // Set global.objc = jsiString.
  runtime->global().setProperty(*runtime, "objc", jsiString);
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
