#import "HostObjectArbitrary.h"
#import <jsi/jsi.h>
#import <Foundation/Foundation.h>

// The constructor
HostObjectArbitrary::HostObjectArbitrary(void *nativeRef)
: m_nativeRef(nativeRef) {}

// The destructor
HostObjectArbitrary::~HostObjectArbitrary() {}

// Returns the value for any given property accessed.
jsi::Value HostObjectArbitrary::get(jsi::Runtime& rt, const jsi::PropNameID& propName) {
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
  
  return jsi::Value::undefined();
}

// Returns the list of keys.
std::vector<jsi::PropNameID> HostObjectArbitrary::getPropertyNames(jsi::Runtime& rt) {
  std::vector<jsi::PropNameID> result;
  // result.push_back(jsi::PropNameID::forAscii(rt, "NSStringTransformLatinToHiragana"));
  return result;
}
