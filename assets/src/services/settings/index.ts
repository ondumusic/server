import { useSyncExternalStore } from "react";
import { definitions } from "./definitions";
import { type Definition, Setting, type SettingValue } from "./setting";

export { DEFAULT_ACCENT_COLOR } from "./definitions";

type Settings<D extends Record<string, Definition>> = {
  [K in keyof D]: Setting<SettingValue<D[K]>>;
} & { reset(): void };

export function createSettings<const D extends Record<string, Definition>>(
  definitions: D,
  storage: Storage,
): Settings<D> {
  const all = Object.entries(definitions).map(
    ([key, definition]) =>
      [key, new Setting(key, storage, definition)] as const,
  );

  // We want to ensure all tabs update when settings change.
  if (typeof window !== "undefined") {
    window.addEventListener("storage", (event) => {
      all.find(([key]) => key === event.key)?.[1].notify();
    });
  }

  return {
    ...(Object.fromEntries(all) as {
      [K in keyof D]: Setting<SettingValue<D[K]>>;
    }),
    reset() {
      for (const [, setting] of all) setting.reset();
    },
  };
}

export const settings = createSettings(definitions, localStorage);

export function useSetting<T>(setting: Setting<T>): T {
  return useSyncExternalStore(setting.subscribe, setting.get);
}
