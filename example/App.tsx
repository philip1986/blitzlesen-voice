import { StyleSheet, Text, View } from "react-native";

import * as BlitzlesenVoice from "blitzlesen-voice";
import { useEffect, useState } from "react";

export default function App() {
  const phrases = ["Hallo I am Philip", "that's a test", "is it working"];

  const [counter, setCounter] = useState(0);
  const [text, setText] = useState(phrases[counter]);
  const [isCorrect, setIsCorrect] = useState(false);
  const [hasPermission, setHasPermission] = useState(false);

  useEffect(() => {
    console.log("Requesting permissions");

    BlitzlesenVoice.requestPermissions().then((res) => {
      console.log("Permissions", setHasPermission(res));
    });
  }, []);

  useEffect(() => {
    if (!hasPermission) {
      return;
    }
    async function listen() {
      console.log("Listening for", text, BlitzlesenVoice.isListening());
      if (BlitzlesenVoice.isListening()) {
        return;
      }

      const [err, res] = await BlitzlesenVoice.listenFor(
        "en_US",
        text,
        ["it's ok"],
        800
      );

      console.log(res.recognisedText);

      setIsCorrect(res.isCorrect);
      if (!res.isCorrect) {
        console.log("Wrong, try again!!");

        listen();
        return;
      }
      const nextWord = (counter + 1) % phrases.length;
      setCounter(nextWord);
      setText(phrases[nextWord]);
    }

    listen();
  }, [text]);

  if (!hasPermission) {
    return (
      <View style={styles.container}>
        <Text>No permission</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text>{text}</Text>
      <Text>{isCorrect ? "Right" : "Wrong"}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
    alignItems: "center",
    justifyContent: "center",
  },
});
