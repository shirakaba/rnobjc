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
  
//  // To break the build with a useless error message:
//  NSLog(@"value as number 2 %f", jsi::Value([NSNumber numberWithDouble:3.1415926]).asNumber());
  
//  auto add = [] (jsi::Runtime& runtime, const jsi::Value& thisValue, const jsi::Value* arguments, size_t count) -> jsi::Value {
//    return jsi::Value(arguments[0].asNumber() + arguments[1].asNumber());
//  };
//  jsi::Function::createFromHostFunction(*runtime, jsi::PropNameID::forAscii(*runtime, "add"), 2, add);
  
  // Create a JSI string from a C string.
  jsi::String jsiString = jsi::String::createFromUtf8(*runtime, "A C string!");

  // Set global.objc = jsiString.
  runtime->global().setProperty(*runtime, "objc", jsi::Object::createFromHostObject(*runtime, std::make_shared<jsi::HostObject>()));
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
