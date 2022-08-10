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
  
  // Stub for now. typeof is correctly returning "object", so we're probably fine.
  if(name == "$$typeof"){
    return jsi::Value::undefined();
  }
  
  NSString *stringTag = m_type == HostObjectArbitraryType::CLASS_INSTANCE ?
    [NSString stringWithFormat: @"HostObjectArbitrary<%@*>", NSStringFromClass([(__bridge NSObject *)m_nativeRef class])] :
    m_type == HostObjectArbitraryType::CLASS ?
      [NSString stringWithFormat: @"HostObjectArbitrary<%@>", NSStringFromClass((__bridge Class)m_nativeRef)] :
      @"HostObjectArbitrary<void *>";
  
  // If you implement this, it'll be used in preference over .toString().
  if(name == "Symbol.toStringTag"){
     return jsi::String::createFromUtf8(rt, stringTag.UTF8String);
  }
  
  if(name == "Symbol.toPrimitive"){
    return jsi::Function::createFromHostFunction(
      rt,
      jsi::PropNameID::forAscii(rt, name),
      1,
      [this, stringTag] (jsi::Runtime& rt, const jsi::Value& thisValue, const jsi::Value* arguments, size_t) -> jsi::Value {
        auto hint = arguments[0].asString(rt).utf8(rt);
        if(hint == "number"){
          if(
             m_type == HostObjectArbitraryType::CLASS_INSTANCE &&
             [(__bridge NSObject *)m_nativeRef isKindOfClass: [NSNumber class]]
          ){
            return convertNSNumberToJSINumber(rt, (__bridge NSNumber *)m_nativeRef);
          }
          // I'd prefer to return NaN here, but can't see how..!
          // Maybe I should return something non-numeric, like null, instead..?
          return jsi::Value(-1);
        }
        
        if(hint == "string"){
          if(
             m_type == HostObjectArbitraryType::CLASS_INSTANCE &&
             [(__bridge NSObject *)m_nativeRef isKindOfClass: [NSString class]]
          ){
            return convertNSStringToJSIString(rt, (__bridge NSString *)m_nativeRef);
          }
        }
        return jsi::String::createFromUtf8(rt, [NSString stringWithFormat: @"[object %@]", stringTag].UTF8String);
      }
    );
  }
  
  if(name == "toJSON"){
    return jsi::Function::createFromHostFunction(
      rt,
      jsi::PropNameID::forAscii(rt, name),
      0,
      [this, stringTag] (jsi::Runtime& rt, const jsi::Value& thisValue, const jsi::Value* arguments, size_t) -> jsi::Value {
        // TODO: support converting enums and structs to JSON.
        // Types like Function and Symbol actually return undefined here, so I'm
        // taking liberties here just to improve console.log() output.
        if(m_type != HostObjectArbitraryType::CLASS_INSTANCE){
          return jsi::String::createFromUtf8(rt, [NSString stringWithFormat: @"[object %@]", stringTag].UTF8String);
        }
        return convertObjCObjectToJSIValue(rt, (__bridge NSObject *)m_nativeRef);
      }
    );
  }
  
  if(m_type != HostObjectArbitraryType::CLASS && m_type != HostObjectArbitraryType::CLASS_INSTANCE){
    // TODO: support indexing into enums and structs.
    return jsi::Value::undefined();
  }

  // If the accessed propName matches a method name, then return a JSI function
  // that proxies through to that method.
  NSString *nameNSString = [NSString stringWithUTF8String:name.c_str()];
  SEL sel = NSSelectorFromString(nameNSString);
  if([(__bridge NSObject *)m_nativeRef respondsToSelector:sel]){
    return invokeMethod(rt, name, sel);
  }

  // If the accessed propName matches a property name, then get that property,
  // convert it from an ObjC type into a JSI one, and return that.
  NSObject *nativeRef = (__bridge NSObject *)m_nativeRef;
  Class clazz = m_type == HostObjectArbitraryType::CLASS ? (Class)nativeRef : [nativeRef class];
  objc_property_t property = class_getProperty(clazz, nameNSString.UTF8String);
  if(property){
    const char *propertyName = property_getName(property);
    if(propertyName){
      NSObject *value = [nativeRef valueForKey:[NSString stringWithUTF8String:propertyName]];
      return convertObjCObjectToJSIValue(rt, value);
    }
  }
  
  // Technically we could proxy ivars as well, but given we're already proxying
  // the very same properties that the ivars access, I think it's okay to just
  // return undefined at this point.
  
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
  
  NSMethodSignature *methodSignature = m_type == HostObjectArbitraryType::CLASS ?
    [clazz methodSignatureForSelector:sel] :
    [clazz instanceMethodSignatureForSelector:sel];
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSignature];
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
      return jsi::Object::createFromHostObject(runtime, std::make_shared<HostObjectArbitrary>((__bridge void *)returnValue));
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
