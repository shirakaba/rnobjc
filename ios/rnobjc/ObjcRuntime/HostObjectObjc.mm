#import "HostObjectObjc.h"
#import <jsi/jsi.h>
#import <Foundation/Foundation.h>

// Returns the value for any given property accessed.
jsi::Value HostObjectObjc::get(jsi::Runtime& rt, const jsi::PropNameID& propName) {
  auto name = propName.utf8(rt);

  if (name == "toString") {
    auto toString = [] (
      jsi::Runtime& rt, const jsi::Value&, const jsi::Value*, size_t
    ) -> jsi::Value {
      return jsi::String::createFromAscii(rt, "[object HostObjectObjc]");
    };

    return jsi::Function::createFromHostFunction(
      rt, jsi::PropNameID::forAscii(rt, "toString"), 0, toString
    );
  }
  
  if (name == "NSStringTransformLatinToHiragana"){
    return jsi::String::createFromUtf8(rt, NSStringTransformLatinToHiragana.UTF8String);
  }
  
  return jsi::Value::undefined();
}

// Returns the list of keys.
std::vector<jsi::PropNameID> HostObjectObjc::getPropertyNames(jsi::Runtime& rt) {
  std::vector<jsi::PropNameID> result;
  result.push_back(jsi::PropNameID::forAscii(rt, "NSStringTransformLatinToHiragana"));
  return result;
}
