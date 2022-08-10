#import "HostObjectArbitrary.h"
#import "JSIUtils.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <React/RCTBridge+Private.h>
#import <ReactCommon/RCTTurboModule.h>

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
  
  // For HostObjectClassInstance, see instancesRespondToSelector, for looking up instance methods.
  
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
  
  SEL sel = NSSelectorFromString([NSString stringWithUTF8String:name.c_str()]);
  if([(__bridge NSObject *)m_nativeRef respondsToSelector:sel]){
    return invokeMethod(rt, name, sel);
  }
//
//  objc_property_t property = class_getProperty([instance_ class], nameNSString.UTF8String);
//  if(property){
//    const char *propertyName = property_getName(property);
//    if(propertyName){
//      NSObject* value = [instance_ valueForKey:[NSString stringWithUTF8String:propertyName]];
//      return convertObjCObjectToJSIValue(runtime, value);
//    }
//  }
  
  
  return jsi::Value::undefined();
}

void HostObjectArbitrary::set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) {
//  auto name = propName.utf8(runtime);
}

jsi::Function HostObjectArbitrary::invokeMethod(jsi::Runtime &runtime, std::string methodName, SEL sel) {
  if(m_type != HostObjectArbitraryType::CLASS && m_type != HostObjectArbitraryType::CLASS_INSTANCE){
    throw jsi::JSError(runtime, [NSString stringWithFormat:@"Cannot invoke method '%s' a native ref of type '%u'; must be a CLASS or CLASS_INSTANCE.", sel_getName(sel), m_type].UTF8String);
  }
  NSObject *nativeRef = (__bridge NSObject *)m_nativeRef;
  Class clazz = m_type == HostObjectArbitraryType::CLASS ? (Class)nativeRef : [nativeRef class];
  Method method = m_type == HostObjectArbitraryType::CLASS ?
    class_getClassMethod(clazz, sel) :
    class_getInstanceMethod(clazz, sel);
  if(!method){
    throw jsi::JSError(runtime, [NSString stringWithFormat:@"class '%s' responded to selector '%s', but the corresponding method was unable to be retrieved.", class_getName(clazz), sel_getName(sel)].UTF8String);
  }
  char observedReturnType[256];
  method_getReturnType(method, observedReturnType, 256);
  
  RCTBridge *bridge = [RCTBridge currentBridge];
  auto jsCallInvoker = bridge.jsCallInvoker;
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[clazz instanceMethodSignatureForSelector:sel]];
  [inv setSelector:sel];
  [inv setTarget:nativeRef];
  
  // arguments 0 and 1 are self and _cmd respectively (effectively not of our concern)
  unsigned int reservedArgs = 2;
  unsigned int argsCount = method_getNumberOfArguments(method) - reservedArgs;
  auto hostFunction = [reservedArgs, nativeRef, clazz, sel, observedReturnType, inv, jsCallInvoker] (jsi::Runtime& runtime, const jsi::Value& thisValue, const jsi::Value* arguments, size_t count) -> jsi::Value {
    // For each argument, convert it to a JSI Value, and set it on the NSInvocation.
    for(unsigned int i = 0; i < count; i++){
      if(!arguments[i].isObject()){
        id objcArg = convertJSIValueToObjCObject(runtime, arguments[i], jsCallInvoker);
        [inv setArgument:&objcArg atIndex: reservedArgs + i];
        continue;
      }
      
      jsi::Object obj = arguments[i].asObject(runtime);
      if(!obj.isHostObject((runtime))){
        id objcArg = convertJSIValueToObjCObject(runtime, arguments[i], jsCallInvoker);
        [inv setArgument:&objcArg atIndex: reservedArgs + i];
        continue;
      }
      
      HostObjectArbitrary* hostObjectArbitrary = dynamic_cast<HostObjectArbitrary*>(obj.asHostObject(runtime).get());
      if(!hostObjectArbitrary){
        throw jsi::JSError(runtime, "Got a JSI HostObject as argument, but couldn't cast to HostObjectArbitrary.");
      }
      
      [inv setArgument:&hostObjectArbitrary->m_nativeRef atIndex: reservedArgs + i];
    }
    [inv invoke];
    
    // If the Obj-C method call returned void, then pass undefined back to JS.
    const char *voidReturnType = "v"; // https://developer.apple.com/documentation/foundation/nsmethodsignature
    if(0 == strncmp(observedReturnType, voidReturnType, strlen(voidReturnType))){
      return jsi::Value::undefined();
    }
    
    id returnValue = NULL;
    [inv getReturnValue:&returnValue];
    
    // If the Obj-C method call returned object (class or class instance), wrap
    // it as a HostObjectArbitrary and pass that back to JS.
    if([returnValue isKindOfClass:[NSObject class]]){
      return jsi::Object::createFromHostObject(runtime, std::make_shared<HostObjectArbitrary>(returnValue));
    }
    
    // Anything else, we treat as if it's serialisable.
    return convertObjCObjectToJSIValue(runtime, returnValue);
  };
  return jsi::Function::createFromHostFunction(runtime, jsi::PropNameID::forUtf8(runtime, methodName), argsCount, hostFunction);
}

// Returns the list of keys.
std::vector<jsi::PropNameID> HostObjectArbitrary::getPropertyNames(jsi::Runtime& rt) {
  std::vector<jsi::PropNameID> result;
  // result.push_back(jsi::PropNameID::forAscii(rt, "NSStringTransformLatinToHiragana"));
  return result;
}
