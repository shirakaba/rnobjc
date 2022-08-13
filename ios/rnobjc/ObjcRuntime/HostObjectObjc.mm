#import "HostObjectObjc.h"
#import "JSIUtils.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>
#import <React/RCTBridge+Private.h>
#import <ReactCommon/RCTTurboModule.h>
#import <dlfcn.h>

HostObjectObjc::HostObjectObjc(void *nativeRef, bool isGlobal): m_nativeRef(nativeRef) {
  if(isGlobal){
    m_type = GLOBAL;
    return;
  }
  
  @try {
    if([(__bridge NSObject *)m_nativeRef isKindOfClass:[NSObject class]]){
      m_type = class_isMetaClass(object_getClass((__bridge NSObject *)m_nativeRef)) ?
        CLASS :
        CLASS_INSTANCE;
      return;
    }
  }
  @catch (NSException *exception) {
    // Handles both ObjC and C++ exceptions as long as it's 64-bit.
  }
  
  m_type = OTHER;
}

jsi::Value HostObjectObjc::get(jsi::Runtime& rt, const jsi::PropNameID& propName) {
  auto name = propName.utf8(rt);
  
  NSString *stringTag;
  if(m_type == CLASS){
    Class ref = (__bridge Class)m_nativeRef;
    stringTag = [NSString stringWithFormat: @"HostObjectObjc<%@>", NSStringFromClass(ref)];
  } else if(m_type == CLASS_INSTANCE){
    NSObject *ref = (__bridge NSObject *)m_nativeRef;
    stringTag = [NSString stringWithFormat: @"HostObjectObjc<%@*>", NSStringFromClass([ref class])];
  } else {
    stringTag = @"HostObjectObjc<void*>";
  }
  
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
        if(hint == "number"){ // Handles: console.log(+hostObjectObjc);
          return m_type == CLASS_INSTANCE && [(__bridge NSObject *)m_nativeRef isKindOfClass: [NSNumber class]] ?
              convertNSNumberToJSINumber(rt, (__bridge NSNumber *)m_nativeRef) :
              jsi::Value(-1); // I'd prefer to return NaN here, but can't see how..!
        } else if(hint == "string"){
          if(
             m_type == CLASS_INSTANCE &&
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
        if(m_type != CLASS_INSTANCE){
          return jsi::String::createFromUtf8(rt, [NSString stringWithFormat: @"[object %@]", stringTag].UTF8String);
        }
        return convertObjCObjectToJSIValue(rt, (__bridge NSObject *)m_nativeRef);
      }
    );
  }
  
  if(m_type == OTHER) return jsi::Value::undefined();
  
  NSString *nameNSString = [NSString stringWithUTF8String:name.c_str()];
  
  if(m_type == GLOBAL){
    if (Class clazz = NSClassFromString(nameNSString)) {
      return jsi::Object::createFromHostObject(rt, std::make_unique<HostObjectObjc>((__bridge void*)clazz, false));
    } else if (Protocol *protocol = NSProtocolFromString(nameNSString)) {
      return jsi::Object::createFromHostObject(rt, std::make_unique<HostObjectObjc>((__bridge void*)protocol, false));
    }
    
    void *value = dlsym(RTLD_MAIN_ONLY, nameNSString.UTF8String);
    if (!value) {
      value = dlsym(RTLD_SELF, nameNSString.UTF8String);
    }
    if (!value) {
      value = dlsym(RTLD_DEFAULT, nameNSString.UTF8String);
    }
    if(!value) {
      throw jsi::JSError(rt, [NSString stringWithFormat:@"ReferenceError: Can't find symbol within this executable: %@", nameNSString].UTF8String);
    }
    
    // Dereference the pointer to the given data.
    // FIXME: if it's not Obj-C object, we're going to crash either upon this
    // typecast or upon sending the isKindOfClass message to it. I'm not sure
    // how best to write the error-handling.
    void* valueDereferenced = *((void**)value);
    
    return jsi::Object::createFromHostObject(rt, std::make_unique<HostObjectObjc>(valueDereferenced, false));
  }
  
  // If the accessed propName matches a method name, then return a JSI function
  // that proxies through to that method.
  SEL sel = NSSelectorFromString(nameNSString);
  if([(__bridge NSObject *)m_nativeRef respondsToSelector:sel]){
    return invokeMethod(rt, name, sel);
  }
  
  // If the accessed propName matches a property name, then get that property,
  // convert it from an ObjC type into a JSI one, and return that.
  NSObject *nativeRef = (__bridge NSObject *)m_nativeRef;
  Class clazz = m_type == CLASS ? (Class)nativeRef : [nativeRef class];
  
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

void HostObjectObjc::set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) {
  // 1️⃣1️⃣ For CLASS and CLASS_INSTANCE only: if the name matches a property, marshal the incoming value and set it.
  // ⚠️ Provisional implementation; very likely doesn't work.
  auto name = propName.utf8(runtime);
  NSString *nameNSString = [NSString stringWithUTF8String:name.c_str()];
  if(m_type != CLASS && m_type != CLASS_INSTANCE){
    throw jsi::JSError(runtime, [NSString stringWithFormat:@"Cannot set '%@' a native ref of type '%u'; must be a CLASS or CLASS_INSTANCE.", nameNSString, m_type].UTF8String);
  }
  
  NSObject *nativeRef = (__bridge NSObject *)m_nativeRef;
  Class clazz = m_type == CLASS ? (Class)nativeRef : [nativeRef class];
  
  RCTBridge *bridge = [RCTBridge currentBridge];
  auto jsCallInvoker = bridge.jsCallInvoker;
  
  void* marshalled;
  if(value.isObject()){
    jsi::Object obj = value.asObject(runtime);
    if(obj.isHostObject((runtime))){
      if(HostObjectObjc* ho = dynamic_cast<HostObjectObjc*>(obj.asHostObject(runtime).get())){
        marshalled = ho->m_nativeRef;
      } else {
        throw jsi::JSError(runtime, "Unwrapping HostObjects other than HostObjectObjc not yet supported!");
      }
    } else {
      marshalled = (__bridge void *)convertJSIValueToObjCObject(runtime, value, jsCallInvoker);
    }
  } else {
    marshalled = (__bridge void *)convertJSIValueToObjCObject(runtime, value, jsCallInvoker);
  }
  
  objc_property_t property = class_getProperty(clazz, nameNSString.UTF8String);
  const char *propertyName = property_getName(property);
  NSString *setterSelectorName = [NSString stringWithFormat:@"set%@:", [NSString stringWithCString:propertyName encoding:NSUTF8StringEncoding].capitalizedString];
  SEL setterSelector = NSSelectorFromString(setterSelectorName);
  ((void (*)(id, SEL, void*))objc_msgSend)(clazz, setterSelector, marshalled);
}

std::vector<jsi::PropNameID> HostObjectObjc::getPropertyNames(jsi::Runtime& rt) {
  // 9️⃣ Return the name for every case that we handle in the get() method above.
  std::vector<jsi::PropNameID> result;
  
  NSObject *nativeRef = (__bridge NSObject *)m_nativeRef;
  Class clazz = m_type == CLASS ? objc_getMetaClass(class_getName((Class)nativeRef)) : [nativeRef class];
  
  // Copy methods.
  unsigned int methodCount;
  Method *methodList = class_copyMethodList(clazz, &methodCount);
  for(unsigned int i = 0; i < methodCount; i++){
    NSString *selectorNSString = NSStringFromSelector(method_getName(methodList[i]));
    result.push_back(jsi::PropNameID::forUtf8(rt, std::string([selectorNSString UTF8String])));
  }
  free(methodList);
  
  // Copy properties. TODO: do the same for subclasses and categories, too.
  unsigned int propCount;
  objc_property_t *propList = class_copyPropertyList(clazz, &propCount);
  for(unsigned int i = 0; i < propCount; i++){
    NSString *propertyNSString = [NSString stringWithUTF8String:property_getName(propList[i])];
    result.push_back(jsi::PropNameID::forUtf8(rt, std::string([propertyNSString UTF8String])));
  }
  free(propList);
  
  return result;
}

jsi::Function HostObjectObjc::invokeMethod(jsi::Runtime &runtime, std::string methodName, SEL sel) {
  if(m_type != CLASS && m_type != CLASS_INSTANCE){
    throw jsi::JSError(runtime, [NSString stringWithFormat:@"Cannot invoke method '%s' a native ref of type '%u'; must be a CLASS or CLASS_INSTANCE.", sel_getName(sel), m_type].UTF8String);
  }
  NSObject *nativeRef = (__bridge NSObject *)m_nativeRef;
  Class clazz = m_type == CLASS ? (Class)nativeRef : [nativeRef class];
  Method method = m_type == CLASS ?
    class_getClassMethod(clazz, sel) :
    class_getInstanceMethod(clazz, sel);
  if(!method){
    throw jsi::JSError(runtime, [NSString stringWithFormat:@"class '%s' responded to selector '%s', but the corresponding method was unable to be retrieved.", class_getName(clazz), sel_getName(sel)].UTF8String);
  }
  char observedReturnType[256];
  method_getReturnType(method, observedReturnType, 256);
  
  RCTBridge *bridge = [RCTBridge currentBridge];
  auto jsCallInvoker = bridge.jsCallInvoker;
  
  NSMethodSignature *methodSignature = m_type == CLASS ?
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
      
      HostObjectObjc* ho = dynamic_cast<HostObjectObjc*>(obj.asHostObject(runtime).get());
      if(!ho){
        throw jsi::JSError(runtime, "Got a JSI HostObject as argument, but couldn't cast to HostObjectObjc.");
      }
      
      [inv setArgument:&ho->m_nativeRef atIndex: reservedArgs + i];
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
      return jsi::Object::createFromHostObject(runtime, std::make_unique<HostObjectObjc>((__bridge void *)returnValue, false));
    }
    
    // Anything else, we treat as if it's serialisable.
    return convertObjCObjectToJSIValue(runtime, returnValue);
  };
  return jsi::Function::createFromHostFunction(runtime, jsi::PropNameID::forUtf8(runtime, methodName), argsCount, hostFunction);
}
