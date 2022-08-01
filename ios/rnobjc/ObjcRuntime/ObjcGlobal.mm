#import "ObjcGlobal.h"
#import <React/RCTBridge+Private.h>
#import <iostream>
#import <stdio.h>

using namespace facebook;

@implementation ObjcGlobal

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

// The installation lifecycle
- (void)setBridge:(RCTBridge *)bridge {
  // Grab a reference to the bridge to use later, during the
  // "invalidate" lifecycle.
  _bridge = bridge;

  RCTCxxBridge *cxxBridge = (RCTCxxBridge*)self.bridge;
  jsi::Runtime *runtime = (jsi::Runtime*)cxxBridge.runtime;
  if (!runtime) {
    return;
  }

  // Write a console log
  std::cout << "Installing our JSI module!\n";
  
  // Create a JSI string from a C string
  jsi::String jsiString = jsi::String::createFromUtf8(*runtime, "A C string!");
  
  // Set a property named "objc" on the global object,
  // taking the JSI string as its value.
  runtime->global().setProperty(*runtime, "objc", jsiString);
}

// The cleanup lifecycle
- (void)invalidate {
  RCTCxxBridge *cxxBridge = (RCTCxxBridge*)self.bridge;
  jsi::Runtime *runtime = (jsi::Runtime*)cxxBridge.runtime;
  if (!runtime) {
    return;
  }
  
  // Overwrite the "objc" property on the global object
  // with `undefined`.
  runtime->global().setProperty(*runtime, "objc", jsi::Value::undefined());
}

@end
