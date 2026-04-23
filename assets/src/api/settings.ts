import { client, type RequestOptions } from "./client";

type ScanType = "full" | "quick";

interface Settings {
  musicPath?: string;
  scanType?: ScanType;
  pollInterval?: number;
}

type SettingsResult =
  | {
      ok: false;
      fields: {
        [key: string]: {
          message: string;
        };
      };
    }
  | {
      ok: true;
    };

export const settingApi = {
  updateSettings(settings: Settings, opts?: RequestOptions) {
    return client.post<Settings, SettingsResult>("/settings", settings, opts);
  },
};
