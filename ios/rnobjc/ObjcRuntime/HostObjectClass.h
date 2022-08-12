#import <jsi/jsi.h>
#import <Foundation/Foundation.h>

using namespace facebook;

class JSI_EXPORT HostObjectClass: public jsi::HostObject {

public:
  HostObjectClass(Class nativeRef);
  Class m_nativeRef;
  
  jsi::Value get(jsi::Runtime& rt, const jsi::PropNameID& name) override;
  void set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) override;
  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;
  
  // Returns a jsi::Function that, when called, will:
  // - invoke a class method with the given selector on the given class;
  // - capture its return value;
  // - marshals it to a JSI Object (either a jsi::Value or a jsi::HostObject as appropriate).
  jsi::Function invokeMethod(jsi::Runtime &runtime, std::string methodName, SEL sel);
};