// Import the native module. On web, it will be resolved to BlitzlesenVoice.web.ts
// and on native platforms to BlitzlesenVoice.ts
import { EventEmitter, Subscription } from "expo-modules-core";
import BlitzlesenVoiceModule from "./BlitzlesenVoiceModule";

export type WordResult = {
  word: string;
  isCorrect: boolean;
  duration: number;
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
  text: string,
  alternatives: string[],
  timeout: number = 1000,
  onDeviceRecognition: boolean = true,
  mistakeConfig: {
    mistakeLimit: number;
    timeLimit: number;
  } = {
    mistakeLimit: 1,
    timeLimit: 0,
  }
): Promise<[Error, VoiceResponse]> {
  return BlitzlesenVoiceModule.listenFor(
    locale,
    text,
    alternatives,
    timeout,
    onDeviceRecognition,
    mistakeConfig
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
