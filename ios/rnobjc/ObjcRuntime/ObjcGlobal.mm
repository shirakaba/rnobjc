#import "ObjcGlobal.h"
#import <React/RCTBridge+Private.h>
#import <React/RCTUtils.h>
#import <iostream>
#import <stdio.h>

#define UNUSED(x) (void)(x)

using namespace facebook;

@implementation ObjcGlobal

@synthesize bridge = _bridge;
@synthesize methodQueue = _methodQueue;

RCT_EXPORT_MODULE()

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

- (void)setBridge:(RCTBridge *)bridge {
  _bridge = bridge;
  _setBridgeOnMainQueue = RCTIsMainQueue();

  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)self.bridge;
  if (!cxxBridge.runtime) {
    return;
  }

  [self install:*(facebook::jsi::Runtime *)cxxBridge.runtime];
}

- (void)invalidate {
  RCTCxxBridge *cxxBridge = (RCTCxxBridge *)self.bridge;
  [self cleanUp:*(facebook::jsi::Runtime *)cxxBridge.runtime];
}

- (void)cleanUp:(jsi::Runtime &)runtime {
  // We can't simply delete properties as far as I can tell, but let's at least
  // try to set them back to undefined.
  runtime.global().setProperty(runtime, "objc", jsi::Value::undefined());
}

- (void)install:(jsi::Runtime &)runtime {
  std::cout << "Installing objc global\n";
  jsi::Object object = jsi::Object::createFromHostObject(runtime, std::make_shared<jsi::HostObject>());
}

@end
