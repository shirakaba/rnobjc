#import <jsi/jsi.h>

using namespace facebook;

class JSI_EXPORT HostObjectObjc: public jsi::HostObject {

public:
  jsi::Value get(jsi::Runtime& rt, const jsi::PropNameID& name) override;
  std::vector<jsi::PropNameID> getPropertyNames(jsi::Runtime& rt) override;
};
