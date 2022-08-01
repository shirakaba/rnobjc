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

// The installation lifecycle
- (void)setBridge:(RCTBridge *)bridge {
  _bridge = bridge;
  _setBridgeOnMainQueue = RCTIsMainQueue();

  RCTCxxBridge *cxxBridge = (RCTCxxBridge*)self.bridge;
  jsi::Runtime *runtime = (jsi::Runtime*)cxxBridge.runtime;
  if (!runtime) {
    return;
  }

  std::cout << "Installing objc global\n";
  
  NSString *objcString = [NSString stringWithFormat:@"Hello, from Obj-C++!"];
  jsi::String jsiString = jsi::String::createFromUtf8(*runtime, objcString.UTF8String);
  
  runtime->global().setProperty(*runtime, "objc", jsiString);
}

// The cleanup lifecycle
- (void)invalidate {
  RCTCxxBridge *cxxBridge = (RCTCxxBridge*)self.bridge;
  jsi::Runtime *runtime = (jsi::Runtime*)cxxBridge.runtime;
  if (!runtime) {
    return;
  }
  
  runtime->global().setProperty(*runtime, "objc", jsi::Value::undefined());
}

@end
