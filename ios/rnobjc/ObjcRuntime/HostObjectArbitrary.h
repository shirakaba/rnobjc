#import <jsi/jsi.h>

using namespace facebook;

class JSI_EXPORT HostObjectArbitrary: public jsi::HostObject {

public:
  HostObjectArbitrary(void *nativeRef);
  ~HostObjectArbitrary();
  void *m_nativeRef;
  jsi::Value get(jsi::Runtime& rt, const jsi::PropNameID& name) override;
  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;
};
