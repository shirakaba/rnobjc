#import "HostObjectObjc.h"
#import <jsi/jsi.h>

// Returns the value for any given property accessed.
jsi::Value HostObjectObjc::get(jsi::Runtime& runtime, const jsi::PropNameID& propName) {
  // 1️⃣ Grab the prop name
  auto name = propName.utf8(runtime);

  if (name == "toString") {
    // 2️⃣ Initialise a HostFunction
    auto toString = [] (jsi::Runtime& runtime, const jsi::Value&, const jsi::Value*, size_t) -> jsi::Value {
      return jsi::String::createFromAscii(runtime, "[object HostObjectObjc]");
    };
    // 3️⃣ Return a JSI Function based on that HostFunction
    return jsi::Function::createFromHostFunction(runtime, jsi::PropNameID::forAscii(runtime, "toString"), 0, toString);
  }
  
  return jsi::Value::undefined();
}

// Returns the list of keys.
std::vector<jsi::PropNameID> HostObjectObjc::getPropertyNames(jsi::Runtime& rt) {
  std::vector<jsi::PropNameID> result;
  // 4️⃣ Add "toString" to the list of keys
//  result.push_back(jsi::PropNameID::forAscii(rt, "toString"));
  return result;
}
