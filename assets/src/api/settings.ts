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
  getSettings(opts?: RequestOptions) {
    return client.get<undefined, Settings>("/settings", opts);
  },

  updateSettings(settings: Settings, opts?: RequestOptions) {
    return client.patch<Settings, SettingsResult>("/settings", settings, opts);
  },
};
