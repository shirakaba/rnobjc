#import "HostObjectArbitrary.h"
#import <jsi/jsi.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// The constructor
HostObjectArbitrary::HostObjectArbitrary(void *nativeRef)
: m_nativeRef(nativeRef) {
  @try {
    if([(__bridge NSObject *)m_nativeRef isKindOfClass:[NSObject class]]){
      m_type = class_isMetaClass(object_getClass((__bridge NSObject *)m_nativeRef)) ?
        HostObjectArbitraryType::CLASS :
        HostObjectArbitraryType::CLASS_INSTANCE;
      return;
    }
  }
  @catch (NSException *exception) {
    // Handles both ObjC and C++ exceptions as long as it's 64-bit.
    // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Exceptions/Articles/Exceptions64Bit.html
  }
  
  m_type = HostObjectArbitraryType::OTHER;
}

// Returns the value for any given property accessed.
jsi::Value HostObjectArbitrary::get(jsi::Runtime& rt, const jsi::PropNameID& propName) {
  auto name = propName.utf8(rt);
  
  if (name == "toString") {
    return jsi::Function::createFromHostFunction(
      rt,
      jsi::PropNameID::forAscii(rt, "toString"),
      0,
      [] (jsi::Runtime& rt, const jsi::Value&, const jsi::Value*, size_t) -> jsi::Value {
        return jsi::String::createFromAscii(rt, "[object HostObjectArbitrary]");
      }
    );
  }
  
  if(name == "$$typeof"){
    // Handles console.log(hostObjectArbitrary);
    return jsi::Value::undefined();
  }
  
  if(name == "Symbol.toStringTag"){
    // Handles: console.log(hostObjectArbitrary.NSString);
    return jsi::String::createFromAscii(rt, "[object HostObjectArbitrary]");
  }
  
  // Runtime type encodings:
  // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100
  
  if(m_type != HostObjectArbitraryType::CLASS_INSTANCE){
    // TODO: consider how to support serialisable HostObjects.
    // Seems like we should allow indexing into enums and structs, but do we
    // also do all serialisable (NSDictionary, NSArray, NSString, std::string)?
    // Do we get that for free with NSObject's runtime getter anyway?
    // Do we auto-marshal totally serialisable objects? I can see it falling
    // apart for NSDictionary<string, any>, large objects, and
    return jsi::Value::undefined();
  }
  
  
  
  return jsi::Value::undefined();
}

void HostObjectArbitrary::set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) {
//  auto name = propName.utf8(runtime);
}

// Returns the list of keys.
std::vector<jsi::PropNameID> HostObjectArbitrary::getPropertyNames(jsi::Runtime& rt) {
  std::vector<jsi::PropNameID> result;
  // result.push_back(jsi::PropNameID::forAscii(rt, "NSStringTransformLatinToHiragana"));
  return result;
}
