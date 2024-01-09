// Import the native module. On web, it will be resolved to BlitzlesenVoice.web.ts
// and on native platforms to BlitzlesenVoice.ts
import { EventEmitter, Subscription } from "expo-modules-core";
import BlitzlesenVoiceModule from "./BlitzlesenVoiceModule";

export type WordResult = {
  word: string;
  isCorrect: boolean;
  duration: number;
  mistake: boolean;
};

export type VoiceResponse = {
  isCorrect: boolean;
  recognisedText: string;
  words: WordResult[];
};

type Error = {
  error: string;
};

const emitter = new EventEmitter(BlitzlesenVoiceModule);

export function listenFor(
  locale: string,
  target: string[][],
  timeout: number = 1000,
  onDeviceRecognition: boolean = true,
  mistakeConfig: {
    mistakeLimit: number;
  } = {
    mistakeLimit: 1,
  },
  firstItemDurationOffset: number = 0,
  volumeThreshold: number = 3
): Promise<[Error, VoiceResponse]> {
  return BlitzlesenVoiceModule.listenFor(
    locale,
    target,
    timeout,
    onDeviceRecognition,
    mistakeConfig,
    firstItemDurationOffset,
    volumeThreshold
  );
}

export function isListening(): boolean | null {
  return BlitzlesenVoiceModule.isListening();
}

export function stopListening(): void {
  return BlitzlesenVoiceModule.stopListening();
}

export function requestPermissions(): Promise<boolean> {
  return BlitzlesenVoiceModule.requestPermissions();
}

export type VolumeChangeEvent = {
  volume: number;
};

export type PartialResultEvent = {
  partialResult: WordResult[];
};

export type MistakeEvent = {
  word: string;
  reason: "timeout" | "tooManyMistakes";
};

export type DebugEvent = {
  recognisedText: string;
};

export function addVolumeListener(
  listener: (event: VolumeChangeEvent) => void
): Subscription {
  return emitter.addListener<VolumeChangeEvent>("onVolumeChange", listener);
}

export function addPartialResultListener(
  listener: (event: PartialResultEvent) => void
): Subscription {
  return emitter.addListener<PartialResultEvent>("onPartialResult", listener);
}

export function addMistakeListner(
  listener: (event: MistakeEvent) => void
): Subscription {
  return emitter.addListener<MistakeEvent>("onMistake", listener);
}

export function addDebugListner(
  listener: (event: DebugEvent) => void
): Subscription {
  return emitter.addListener<DebugEvent>("onDebug", listener);
}

export function train(
  locale: string,
  phrases: string[],
  graphemeToPhonems: string[][]
): Promise<void> {
  return BlitzlesenVoiceModule.train(locale, phrases, graphemeToPhonems);
}
