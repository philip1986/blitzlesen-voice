import { StyleSheet, Text, View } from "react-native";

import * as BlitzlesenVoice from "blitzlesen-voice";
import { useEffect, useState } from "react";

interface Word {
  word: string;
  isCorrect: boolean;
}

function toWords(text: string): Word[] {
  return text.split(" ").map((w) => ({
    word: w,
    isCorrect: false,
  }));
}

export default function App() {
  const phrases = [
    "Auf dem Tisch lag eine schwarze Katze",
    "Sie war sehr müde",
    "test"
  ];

  const [counter, setCounter] = useState(0);
  const [text, setText] = useState(toWords(phrases[counter]));

  const [isCorrect, setIsCorrect] = useState(false);
  const [hasPermission, setHasPermission] = useState(false);
  const [volume, setVolume] = useState(0);

  useEffect(() => {
    console.log("Requesting permissions");

    BlitzlesenVoice.requestPermissions().then((res) => {
      setHasPermission(res);
    });
  }, []);

  useEffect(() => {
    const subscription = BlitzlesenVoice.addVolumeListener(({ volume }) => {
      setVolume(volume);
    });

    return () => subscription.remove();
  }, []);

  useEffect(() => {
    const subscription = BlitzlesenVoice.addPartialResultListener(
      ({partialResult} ) => { 
        setText(partialResult);
      }
    );

    return () => subscription.remove();
  }, []);

  useEffect(() => {
    if (!hasPermission) {
      return;
    }
    async function listen() {
      // console.log("Listening for", text, BlitzlesenVoice.isListening());
      if (BlitzlesenVoice.isListening()) {
        return;
      }

      const [err, res] = await BlitzlesenVoice.listenFor(
        "de-DE",
        text.map((w) => w.word).join(" "),
        ["it's ok"],
        20000,
        false
      );

      console.log('>>>>>', res);

      setIsCorrect(res.isCorrect);
      if (!res.isCorrect) {
        console.log("Wrong, try again!!");

        listen();
        return;
      }
      const nextWord = (counter + 1) % phrases.length;
      setCounter(nextWord);
      setText(toWords(phrases[nextWord]));
    }

    listen();
  }, [text, hasPermission]);

  if (!hasPermission) {
    return (
      <View style={styles.container}>
        <Text>No permission</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text>
        {text.map((w, i) => (
          <Text key={i} style={{ color: w.isCorrect ? "grey" : "black" }}>
            {w.word}{" "}
          </Text>
        ))}
      </Text>
      <Text>Volume: {volume}</Text>
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
