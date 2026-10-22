import { formatHex, oklch, parse, wcagContrast } from "culori";

function generateAccentPalette(baseColor: string): Record<string, string> {
  const parsed = parse(baseColor);
  const base = oklch(parsed);
  if (!parsed || !base) throw new Error(`Invalid color: ${baseColor}`);

  const shades = {
    50: { l: 0.97, c: base.c * 0.12 },
    100: { l: 0.94, c: base.c * 0.22 },
    200: { l: 0.885, c: base.c * 0.4 },
    300: { l: 0.8, c: base.c * 0.62 },
    400: { l: 0.7, c: base.c * 0.82 },
    500: { l: base.l, c: base.c },
    600: { l: 0.545, c: base.c * 0.96 },
    700: { l: 0.46, c: base.c * 0.88 },
    800: { l: 0.375, c: base.c * 0.74 },
    900: { l: 0.3, c: base.c * 0.58 },
    950: { l: 0.22, c: base.c * 0.42 },
  };

  return Object.fromEntries(
    Object.entries(shades).map(([shade, { l, c }]) => [
      shade,
      formatHex({ mode: "oklch", l, c, h: base.h }),
    ]),
  );
}

// The blue from the Ondu branding
export const DEFAULT_ACCENT_COLOR = "#3868f1";

export function getAccentColor() {
  return localStorage.getItem("baseAccentColor") ?? DEFAULT_ACCENT_COLOR;
}

function darkModeColor(baseColor: string) {
  const base = oklch(parse(baseColor));
  if (!base) throw new Error(`Invalid color: ${baseColor}`);

  const l = base.l + Math.max(0, 0.7 - base.l) * 0.5;
  return formatHex({ ...base, l });
}

export function applyAccentColor() {
  const baseColor = getAccentColor();
  const palette = generateAccentPalette(baseColor);
  const root = document.documentElement;

  for (const [shade, hex] of Object.entries(palette)) {
    root.style.setProperty(`--accent-${shade}`, hex);
  }

  root.style.removeProperty("--accent-500");
  root.style.setProperty("--accent-light-500", palette[500]);
  root.style.setProperty("--accent-dark-500", darkModeColor(baseColor));
}

export function updateAccentColor(baseColor: string) {
  localStorage.setItem("baseAccentColor", baseColor);
  applyAccentColor();
}

export function isAccessible(baseColor: string): boolean {
  return wcagContrast(baseColor, "white") >= 3;
}
