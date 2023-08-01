import * as React from 'react';

import { BlitzlesenVoiceViewProps } from './BlitzlesenVoice.types';

export default function BlitzlesenVoiceView(props: BlitzlesenVoiceViewProps) {
  return (
    <div>
      <span>{props.name}</span>
    </div>
  );
}
