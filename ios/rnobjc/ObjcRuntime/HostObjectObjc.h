#import <jsi/jsi.h>

using namespace facebook;

enum HostObjectObjcType {
  OTHER,
  CLASS,
  CLASS_INSTANCE,
  GLOBAL,
};

class JSI_EXPORT HostObjectObjc: public jsi::HostObject {

public:
  HostObjectObjc(void *nativeRef, bool isGlobal);
  void *m_nativeRef;
  HostObjectObjcType m_type;
  
  jsi::Value get(jsi::Runtime& rt, const jsi::PropNameID& name) override;
  void set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) override;
  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;
  
  jsi::Function invokeMethod(jsi::Runtime &runtime, std::string methodName, SEL sel);
};
