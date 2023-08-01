import { StyleSheet, Text, View } from 'react-native';

import * as BlitzlesenVoice from 'blitzlesen-voice';

export default function App() {
  return (
    <View style={styles.container}>
      <Text>{BlitzlesenVoice.hello()}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
