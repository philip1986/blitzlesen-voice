import { StyleSheet, Text, View } from "react-native";

import * as BlitzlesenVoice from "blitzlesen-voice";
import { useEffect, useState } from "react";

export default function App() {
  const words = [
    "Hallo ich bin Philip",
    "Maus",
    "Klaus",
    "das ist",
    "ein Test",
  ];

  const [counter, setCounter] = useState(0);
  const [word, setWord] = useState(words[counter]);
  const [isCorrect, setIsCorrect] = useState(false);

  useEffect(() => {
    async function listen() {
      console.log("Listening for", word);

      const [err, res] = await BlitzlesenVoice.listenFor("de_DE", word, [
        "Fahrrad",
      ]);

      console.log(err, res);

      setIsCorrect(res.isCorrect);
      if (!res.isCorrect) {
        listen();
        return;
      }
      const nextWord = (counter + 1) % words.length;
      setCounter(nextWord);
      setWord(words[nextWord]);
    }

    listen();
  }, [word]);

  return (
    <View style={styles.container}>
      <Text>{word}</Text>
      <Text>{isCorrect}</Text>
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
