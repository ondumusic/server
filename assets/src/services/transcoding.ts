const PRESET_KEY = "transcodingPreset";

export class TranscodingService {
  get preset(): string | null {
    return localStorage.getItem(PRESET_KEY);
  }

  set preset(preset: string | null) {
    if (preset) {
      localStorage.setItem(PRESET_KEY, preset);
    } else {
      localStorage.removeItem(PRESET_KEY);
    }
  }
}

export const transcoding = new TranscodingService();
