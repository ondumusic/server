const writeToDataView = (view: DataView, offset: number, string: string) => {
  for (let i = 0; i < string.length; i++) {
    view.setUint8(offset + i, string.charCodeAt(i));
  }
};

export function generateSilentTrack(duration: number, sampleRate: number) {
  // This will generate a mono (1 channel) silent wav file and return it
  // as an object url.
  const frameCount = duration * sampleRate;
  const arrayBuffer = new ArrayBuffer(44 + frameCount * 2);
  const view = new DataView(arrayBuffer);

  // Write the WAV file headers as documented here:
  // https://en.wikipedia.org/wiki/WAV

  // Master RIFF chunk
  writeToDataView(view, 0, "RIFF"); // Identifier
  view.setUint32(4, 36 + frameCount * 2, true); // File size minus 8 bytes
  writeToDataView(view, 8, "WAVE"); // Format

  // Chunk describing data format
  writeToDataView(view, 12, "fmt "); // Identifier
  view.setUint32(16, 16, true); // Chunk size minus 8 bytes (== 16 bytes)
  view.setUint16(20, 1, true); // Audio format (1 = PCM)
  view.setUint16(22, 1, true); // Number of channels
  view.setUint32(24, sampleRate, true); // Sample rate (in hertz)
  view.setUint32(28, sampleRate * 2, true); // Number of bytes to read per second (Frequency * BytePerBloc).
  view.setUint16(32, 2, true); // Number of bytes per block (NbrChannels * BitsPerSample / 8).
  view.setUint16(34, 16, true); // Number of bits per sample

  // Chunk containing sampled data
  writeToDataView(view, 36, "data"); // Identifier
  view.setUint32(40, frameCount * 2, true); // SampledData size

  // The rest of the ArrayBuffer already contains duration amount of nothing.
  const blob = new Blob([arrayBuffer], { type: "audio/wav" });
  return URL.createObjectURL(blob);
}
