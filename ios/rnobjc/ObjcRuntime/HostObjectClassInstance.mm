#import "HostObjectClass.h"
#import "HostObjectClassInstance.h"
#import "JSIUtils.h"
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <React/RCTBridge+Private.h>
#import <ReactCommon/RCTTurboModule.h>

// The constructor
HostObjectClassInstance::HostObjectClassInstance(NSObject *nativeRef)
: m_nativeRef(nativeRef) {}

// Returns the value for any given property accessed.
jsi::Value HostObjectClassInstance::get(jsi::Runtime& rt, const jsi::PropNameID& propName) {
  auto name = propName.utf8(rt);
  
  // Stub for now. typeof is correctly returning "object", so we're probably fine.
  if(name == "$$typeof"){
    return jsi::Value::undefined();
  }
  
  NSString *stringTag = [NSString stringWithFormat: @"HostObjectClassInstance<%@*>", NSStringFromClass([m_nativeRef class])];
  
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
          if([m_nativeRef isKindOfClass: [NSNumber class]]){
            return convertNSNumberToJSINumber(rt, (NSNumber *)m_nativeRef);
          }
          // I'd prefer to return NaN here, but can't see how..!
          // Maybe I should return something non-numeric, like null, instead..?
          return jsi::Value(-1);
        }

        if(hint == "string"){
          if([m_nativeRef isKindOfClass: [NSString class]]){
            return convertNSStringToJSIString(rt, (NSString *)m_nativeRef);
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
        return convertObjCObjectToJSIValue(rt, m_nativeRef);
      }
    );
  }
  
  // If the accessed propName matches a method name, then return a JSI function
  // that proxies through to that method.
  NSString *nameNSString = [NSString stringWithUTF8String:name.c_str()];
  SEL sel = NSSelectorFromString(nameNSString);
  if([m_nativeRef respondsToSelector:sel]){
    return invokeMethod(rt, name, sel);
  }
  
  // If the accessed propName matches a property name, then get that property,
  // convert it from an ObjC type into a JSI one, and return that.
  objc_property_t property = class_getProperty([m_nativeRef class], nameNSString.UTF8String);
  if(property){
    const char *propertyName = property_getName(property);
    if(propertyName){
      NSObject *value = [m_nativeRef valueForKey:[NSString stringWithUTF8String:propertyName]];
      return convertObjCObjectToJSIValue(rt, value);
    }
  }
  
  // Technically we could proxy ivars as well, but given we're already proxying
  // the very same properties that the ivars access, I think it's okay to just
  // return undefined at this point.
  
  return jsi::Value::undefined();
}

void HostObjectClassInstance::set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) {
//  auto name = propName.utf8(runtime);
}

jsi::Function HostObjectClassInstance::invokeMethod(jsi::Runtime &runtime, std::string methodName, SEL sel) {
  Class clazz = [m_nativeRef class];
  Method method = class_getInstanceMethod(clazz, sel);
  if(!method){
    throw jsi::JSError(runtime, [NSString stringWithFormat:@"class '%s' responded to selector '%s', but the corresponding method was unable to be retrieved.", class_getName(clazz), sel_getName(sel)].UTF8String);
  }
  char observedReturnType[256];
  method_getReturnType(method, observedReturnType, 256);
  
  RCTBridge *bridge = [RCTBridge currentBridge];
  auto jsCallInvoker = bridge.jsCallInvoker;
  
  NSMethodSignature *methodSignature = [clazz instanceMethodSignatureForSelector:sel];
  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSignature];
  [inv setSelector:sel];
  [inv setTarget:m_nativeRef];
  
  // arguments 0 and 1 are self and _cmd respectively (effectively not of our concern)
  unsigned int reservedArgs = 2;
  unsigned int argsCount = method_getNumberOfArguments(method) - reservedArgs;
  auto hostFunction = [this, reservedArgs, clazz, sel, observedReturnType, inv, jsCallInvoker] (jsi::Runtime& runtime, const jsi::Value& thisValue, const jsi::Value* arguments, size_t count) -> jsi::Value {
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
      
      if(HostObjectClass* ho = dynamic_cast<HostObjectClass*>(obj.asHostObject(runtime).get())){
        [inv setArgument:&ho->m_nativeRef atIndex: reservedArgs + i];
      } else if(HostObjectClassInstance* ho = dynamic_cast<HostObjectClassInstance*>(obj.asHostObject(runtime).get())){
        [inv setArgument:&ho->m_nativeRef atIndex: reservedArgs + i];
      } else {
        throw jsi::JSError(runtime, "Got a JSI HostObject as argument, but wasn't one that from our ObjcRuntime library.");
      }
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
    // it as a HostObjectClassInstance and pass that back to JS.
    if([returnValue isKindOfClass:[NSObject class]]){
      return class_isMetaClass(object_getClass(returnValue)) ?
        jsi::Object::createFromHostObject(
          runtime,
          std::make_shared<HostObjectClass>(returnValue)
        ) :
        jsi::Object::createFromHostObject(
          runtime,
          std::make_shared<HostObjectClassInstance>(returnValue)
        );
    }
    
    // Anything else, we treat as if it's serialisable.
    return convertObjCObjectToJSIValue(runtime, returnValue);
  };
  return jsi::Function::createFromHostFunction(runtime, jsi::PropNameID::forUtf8(runtime, methodName), argsCount, hostFunction);
}

// Returns the list of keys.
std::vector<jsi::PropNameID> HostObjectClassInstance::getPropertyNames(jsi::Runtime& rt) {
  std::vector<jsi::PropNameID> result;
  return result;
}
