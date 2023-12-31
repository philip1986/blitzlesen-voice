import { StyleSheet, Text, View } from "react-native";

import * as BlitzlesenVoice from "blitzlesen-voice";
import { useEffect, useState } from "react";

interface Word {
  word: string;
  targets: string[];
  isCorrect: boolean;
}

function toWords(text: string[][]): Word[] {
  return text.map((w) => ({
    word: w[0],
    targets: w,
    isCorrect: false,
  }));
}

export default function App() {
  const phrases = [
    [["lebendig"]],
    [["Du"], ["winkst"], ["Oma"]],
    [["Die"], ["Kuh"]],
  ];

  // const phrases = [
  //   "das",
  //   "ist",
  //   "ein",
  //   "test"
  // ];

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
      ({ partialResult }) => {
        setText((p) =>
          partialResult.map((w, i) => ({
            ...w,
            targets: p[i].targets,
          }))
        );
      }
    );

    return () => subscription.remove();
  }, []);

  useEffect(() => {
    const subscription = BlitzlesenVoice.addDebugListner(
      ({ recognisedText }) => {
        console.log("[debug] recognisedText", recognisedText);
      }
    );

    return () => subscription.remove();
  }, []);

  useEffect(() => {
    const subscription = BlitzlesenVoice.addMistakeListner(
      ({ word, reason }) => {
        console.log("[debug] mistake", word, reason);
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

      try {
        const s = Date.now();
        await BlitzlesenVoice.train(
          "de_DE",
          ["Du winkst Oma"],
          [["Kuh", "k u:"]]
        );
        console.log("Training took", Date.now() - s, "ms");
      } catch (e) {
        console.log(e);
      }

      const [err, res] = await BlitzlesenVoice.listenFor(
        "de_DE",
        text.map((w) => w.targets),
        20000,
        true,
        {
          mistakeLimit: 1,
        }
      );

      console.log(">>>>>", res);

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
