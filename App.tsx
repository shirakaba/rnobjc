/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * Generated with the TypeScript template
 * https://github.com/react-native-community/react-native-template-typescript
 *
 * @format
 */

import React, {type PropsWithChildren} from 'react';
import {
  SafeAreaView,
  ScrollView,
  StatusBar,
  StyleSheet,
  Text,
  useColorScheme,
  View,
} from 'react-native';

import {
  Colors,
  DebugInstructions,
  Header,
  LearnMoreLinks,
  ReloadInstructions,
} from 'react-native/Libraries/NewAppScreen';

declare var objc: any;

const Section: React.FC<
  PropsWithChildren<{
    title: string;
  }>
> = ({children, title}) => {
  const isDarkMode = useColorScheme() === 'dark';
  return (
    <View style={styles.sectionContainer}>
      <Text
        style={[
          styles.sectionTitle,
          {
            color: isDarkMode ? Colors.white : Colors.black,
          },
        ]}>
        {title}
      </Text>
      <Text
        style={[
          styles.sectionDescription,
          {
            color: isDarkMode ? Colors.light : Colors.dark,
          },
        ]}>
        {children}
      </Text>
    </View>
  );
};

const App = () => {
  const isDarkMode = useColorScheme() === 'dark';

  const backgroundStyle = {
    backgroundColor: isDarkMode ? Colors.darker : Colors.lighter,
  };

  React.useEffect(() => {
    // console.log('objc:', objc);
    // console.log('objc.NSString:', objc.NSString);
    // console.log('objc.NSString.alloc().init():', objc.NSString.alloc().init());

    // Crashing because NSInvocation can only accept Obj-C arguments and all the
    // constructors for NSNumber require a C number.
    // console.log(
    //   "objc.NSNumber.alloc()['initWithInteger:'](123)",
    //   objc.NSNumber.alloc()['initWithInteger:'](123),
    // );
    // console.log(
    //   "objc.NSNumber['numberWithInteger:'](123)",
    //   objc.NSNumber['numberWithInteger:'](123),
    // );

    // objc runtime can't see any allKeys property at all.
    // console.log(
    //   'objc.NSDictionary.alloc().init().allKeys',
    //   objc.NSDictionary.alloc().init().allKeys,
    // );

    // console.log(objc.NSString.alloc()['initWithString:']('Hello'));
    // console.log(objc.NSNumber.alloc()['initWithInteger:'](123));
    // console.log(
    //   `objc.NSString.alloc().init(): ${objc.NSString.alloc().init()}`,
    // );
    // console.log(`typeof objc.NSString: ${typeof objc.NSString}`);
    // console.log(
    //   // eslint-disable-next-line no-self-compare
    //   `objc.NSString === objc.NSString: ${objc.NSString === objc.NSString}`,
    // );
    // console.log('Object.keys(objc):', Object.keys(objc));

    const hello = objc.NSString.alloc()['initWithString:']('Hello');
    const helloWorld = hello['stringByAppendingString:'](', world!');
    console.log('Concatenate two NSStrings:', helloWorld);

    // console.log(
    //   'Marshal UTF-8 text back and forth, given "白樺":',
    //   objc.NSString.alloc()['initWithString:']('白樺'),
    // );

    // console.log(
    //   'Get unicode name for each character, given "🐝":',
    //   objc.NSString.alloc()
    //     ['initWithString:']('🐝')
    //     ['stringByApplyingTransform:reverse:']('Name-Any', false),
    // );

    // // Fun with Foundation String Transforms!
    // // @see https://nshipster.com/ios9/
    // // @see https://nshipster.com/cfstringtransform/
    // // @see https://sites.google.com/site/icuprojectuserguide/transforms/general#TOC-ICU-Transliterators
    // // @see https://twitter.com/LinguaBrowse/status/1390225265612181505?s=20
    // console.log(
    //   'Convert Chinese script from Trad. -> Simp., given "漢字簡化爭論":',
    //   objc.NSString.alloc()
    //     ['initWithString:']('漢字簡化爭論')
    //     ['stringByApplyingTransform:reverse:']('Simplified-Traditional', false),
    // );

    // console.log(
    //   'Look up the global variable "NSStringTransformLatinToHiragana" in order to transliterate Japanese Hiragana to Latin, given "しらかば":',
    //   objc.NSString.alloc()
    //     ['initWithString:']('しらかば')
    //     ['stringByApplyingTransform:reverse:'](
    //       (objc as any).NSStringTransformLatinToHiragana,
    //       false,
    //     ),
    // );

    // console.log(
    //   'Do the same, this time using the equivalent Core Foundation symbol, "kCFStringTransformToLatin":',
    //   objc.NSString.alloc()
    //     ['initWithString:']('しらかば')
    //     ['stringByApplyingTransform:reverse:'](
    //       (objc as any).kCFStringTransformToLatin,
    //       false,
    //     ),
    // );

    // console.log(
    //   'Transliterate Korean Hangul to Latin, given "안녕하세요":',
    //   objc.NSString.alloc()
    //     ['initWithString:']('안녕하세요')
    //     ['stringByApplyingTransform:reverse:']('Latin-Hangul', false),
    // );
  }, []);

  return (
    <SafeAreaView style={backgroundStyle}>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        style={backgroundStyle}>
        <Header />
        <View
          style={{
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
          }}>
          <Section title="Step One">
            Edit <Text style={styles.highlight}>App.tsx</Text> to change this
            screen and then come back to see your edits.
          </Section>
          <Section title="See Your Changes">
            <ReloadInstructions />
          </Section>
          <Section title="Debug">
            <DebugInstructions />
          </Section>
          <Section title="Learn More">
            Read the docs to discover what to do next:
          </Section>
          <LearnMoreLinks />
        </View>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  sectionContainer: {
    marginTop: 32,
    paddingHorizontal: 24,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
  },
  sectionDescription: {
    marginTop: 8,
    fontSize: 18,
    fontWeight: '400',
  },
  highlight: {
    fontWeight: '700',
  },
});

export default App;
