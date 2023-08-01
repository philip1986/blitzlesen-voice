import { NativeModulesProxy, EventEmitter, Subscription } from 'expo-modules-core';

// Import the native module. On web, it will be resolved to BlitzlesenVoice.web.ts
// and on native platforms to BlitzlesenVoice.ts
import BlitzlesenVoiceModule from './BlitzlesenVoiceModule';
import BlitzlesenVoiceView from './BlitzlesenVoiceView';
import { ChangeEventPayload, BlitzlesenVoiceViewProps } from './BlitzlesenVoice.types';

// Get the native constant value.
export const PI = BlitzlesenVoiceModule.PI;

export function hello(): string {
  return BlitzlesenVoiceModule.hello();
}

export async function setValueAsync(value: string) {
  return await BlitzlesenVoiceModule.setValueAsync(value);
}

const emitter = new EventEmitter(BlitzlesenVoiceModule ?? NativeModulesProxy.BlitzlesenVoice);

export function addChangeListener(listener: (event: ChangeEventPayload) => void): Subscription {
  return emitter.addListener<ChangeEventPayload>('onChange', listener);
}

export { BlitzlesenVoiceView, BlitzlesenVoiceViewProps, ChangeEventPayload };
