
```objc++
// [Obj-C] Create an NSString
NSString *objcString = [NSString stringWithFormat:@"A native string!"];
// [C] Convert it to a C string in UTF-8 format
const char *cString = objcString.UTF8String;
// [C++] Create a JSI string using that C string
jsi::String jsiString = jsi::String::createFromUtf8(*runtime, cString);
```