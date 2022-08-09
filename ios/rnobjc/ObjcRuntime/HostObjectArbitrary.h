#import <jsi/jsi.h>

using namespace facebook;

enum HostObjectArbitraryType {
  OTHER,
  CLASS,
  CLASS_INSTANCE,
//  SERIALISABLE,
};

class JSI_EXPORT HostObjectArbitrary: public jsi::HostObject {

public:
  HostObjectArbitrary(void *nativeRef);
  void *m_nativeRef;
  HostObjectArbitraryType m_type;
  jsi::Value get(jsi::Runtime& rt, const jsi::PropNameID& name) override;
  void set(jsi::Runtime& runtime, const jsi::PropNameID& propName, const jsi::Value& value) override;
  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;
};
