#import "HostObjectObjc.h"

HostObjectObjc::HostObjectObjc(void *nativeRef, bool isGlobal): m_nativeRef(nativeRef) {
  // 1️⃣ Determine whether nativeRef is a class, class instance, or something else, and set m_type accordingly.
}

jsi::Value HostObjectObjc::get(jsi::Runtime& rt, const jsi::PropNameID& propName) {
  auto name = propName.utf8(rt);
  if(name == "Symbol.toStringTag"){ /* 2️⃣ Handle console.log */ }
  if(name == "Symbol.toPrimitive"){ /* 3️⃣ Handle things like the + operator */ }
  if(name == "toJSON"){ /* 4️⃣ Handle some more console.log cases */ }
  if(m_type == HostObjectObjcType::GLOBAL){
    // 5️⃣ If Obj-C has a _class_ with this name, return a HostObjectObjc wrapping it.
    // 6️⃣ Else, if Obj-C has a _variable_ with this name, return a HostObjectObjc wrapping it.
  } else if(m_type == HostObjectObjcType::CLASS){
    // 7️⃣ If nativeRef has a _class method_ with this name, return a JSI function that proxies it.
    // 8️⃣ Else, if nativeRef has a _class property_ with this name, get that value, marshal it, and return it.
  } else if(m_type == HostObjectObjcType::CLASS_INSTANCE){
    // 9️⃣ If nativeRef has a _instance method_ with this name, return a JSI function that proxies it.
    // 🔟 Else, if nativeRef has a _instance property_ with this name, get that value, marshal it, and return it.
  }
  return jsi::Value::undefined();
}

void HostObjectObjc::set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) {
  // 1️⃣1️⃣ For CLASS and CLASS_INSTANCE only: if the name matches a property, marshal the incoming value and set it.
}

std::vector<jsi::PropNameID> HostObjectObjc::getPropertyNames(jsi::Runtime& rt) {
  // 1️⃣2️⃣ Return the name for every case that we handle in the get() method above.
  return std::vector<jsi::PropNameID>();
}
