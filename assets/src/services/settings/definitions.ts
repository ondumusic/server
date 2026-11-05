import type { Definition } from "./setting";

export const DEFAULT_ACCENT_COLOR = "#3868f1";

export const definitions = {
  theme: {
    type: "string",
    defaultValue: "auto",
  },
  baseAccentColor: {
    type: "string",
    defaultValue: DEFAULT_ACCENT_COLOR,
  },
  albumSort: {
    type: "string",
    defaultValue: "artistSortName",
  },
  albumSortDir: {
    type: "string",
    defaultValue: "asc",
    oneOf: ["asc", "desc"],
  },
  showArtistArtwork: {
    type: "boolean",
    defaultValue: true,
  },
  recordPlays: {
    type: "boolean",
    defaultValue: true,
  },
  transcodingPreset: {
    type: "string",
    defaultValue: null,
  },
} satisfies Record<string, Definition>;
