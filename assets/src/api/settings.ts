import type { ScanType, Settings } from "../types";
import { client, type RequestOptions } from "./client";

interface SettingsInput {
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
      settings: Settings;
    };

export const settingApi = {
  getSettings(opts?: RequestOptions) {
    return client.get<undefined, Settings>("/settings", opts);
  },

  updateSettings(settings: SettingsInput, opts?: RequestOptions) {
    return client.patch<SettingsInput, SettingsResult>(
      "/settings",
      settings,
      opts,
    );
  },
};
