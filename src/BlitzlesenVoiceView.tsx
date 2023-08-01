import { requireNativeViewManager } from 'expo-modules-core';
import * as React from 'react';

import { BlitzlesenVoiceViewProps } from './BlitzlesenVoice.types';

const NativeView: React.ComponentType<BlitzlesenVoiceViewProps> =
  requireNativeViewManager('BlitzlesenVoice');

export default function BlitzlesenVoiceView(props: BlitzlesenVoiceViewProps) {
  return <NativeView {...props} />;
}
