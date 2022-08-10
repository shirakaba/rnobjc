#import "HostObjectArbitrary.h"
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
    throw jsi::JSError(runtime, [NSString stringWithFormat:@"Cannot invoke method '%s' a native ref of type '%u'; must be CLASS or CLASS_INSTANCE.", sel_getName(sel), m_type].UTF8String);
  }
  NSObject *nativeRef = (__bridge NSObject *)m_nativeRef;
  Class clazz = m_type == HostObjectArbitraryType::CLASS ? (Class)nativeRef : [nativeRef class];
  Method method = HostObjectArbitraryType::CLASS ?
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
    for(unsigned int i = 0; i < count; i++){
      if(!arguments[i].isObject()){
        id objcArg = convertJSIValueToObjCObject(runtime, arguments[i], jsCallInvoker);
        [inv setArgument:&objcArg atIndex: reservedArgs + i];
        continue;
      }
      
      if(!obj.isHostObject((runtime))){
        id objcArg = convertJSIValueToObjCObject(runtime, arguments[i], jsCallInvoker);
        [inv setArgument:&objcArg atIndex: reservedArgs + i];
        continue;
      }
      
      jsi::Object obj = arguments[i].asObject(runtime);
      if(HostObjectClass* hostObjectClass = dynamic_cast<HostObjectClass*>(obj.asHostObject(runtime).get())){
        [inv setArgument:&hostObjectClass->clazz_ atIndex: reservedArgs + i];
      } else if(HostObjectClassInstance* hostObjectClassInstance = dynamic_cast<HostObjectClassInstance*>(obj.asHostObject(runtime).get())){
        [inv setArgument:&hostObjectClassInstance->instance_ atIndex: reservedArgs + i];
      } else {
        throw jsi::JSError(runtime, "invokeClassInstanceMethod: Unwrapping HostObjects other than ClassHostObject not yet supported!");
      }
    }
    [inv invoke];
    
    // @see https://developer.apple.com/documentation/foundation/nsmethodsignature
    const char *voidReturnType = "v";
    if(0 == strncmp(observedReturnType, voidReturnType, strlen(voidReturnType))){
      return jsi::Value::undefined();
    }
    
    id returnValue = NULL;
    [inv getReturnValue:&returnValue];
    
    // isKindOfClass checks whether the returnValue is an instance of any subclass of NSObject or NSObject itself.
    // There is also isMemberOfClass if we ever want to check whether it is an instance of NSObject (not a subclass).
    if([returnValue isKindOfClass:[NSObject class]]){
      return jsi::Object::createFromHostObject(runtime, std::make_shared<HostObjectClassInstance>(returnValue));
    }
    
    // If we get blocked by "Did you forget to nest alloc and init?", we may be restricted to [NSString new].
    
    // Boy is this unsafe..!
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
