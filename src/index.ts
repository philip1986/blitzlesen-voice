// Import the native module. On web, it will be resolved to BlitzlesenVoice.web.ts
// and on native platforms to BlitzlesenVoice.ts
import BlitzlesenVoiceModule from "./BlitzlesenVoiceModule";

export type VoiceResponse = {
  isCorrect: boolean;
  recognisedText: string;
};

type Error = {
  error: string;
};

export function listenFor(
  locale: string,
  word: string,
  alternatives: string[],
  timeout: number = 1000,
  onDeviceRecognition: boolean = false
): Promise<[Error, VoiceResponse]> {
  return BlitzlesenVoiceModule.listenFor(
    locale,
    word,
    alternatives,
    timeout,
    onDeviceRecognition
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
