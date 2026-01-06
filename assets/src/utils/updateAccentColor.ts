/**
 * This function is an experiment to theme the UI based around the currently
 * playing album artwork. Most of the code in this file is AI generated. I am
 * not happy with the results all of the time, but in general most of the time
 * it seems to be fine. Room for improvement, but this is not the main focus
 * right now as it's just an experiment.
 **/
import { formatCss, oklch } from "culori";

// Extract accent color from image element (avoiding extremes)
function extractAccentColor(img: HTMLImageElement): [number, number, number] {
  const canvas = document.createElement("canvas");
  const ctx = canvas.getContext("2d");
  if (!ctx) return [0, 0, 0];

  // Scale down for performance
  const scale = 0.1;
  canvas.width = img.width * scale;
  canvas.height = img.height * scale;

  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;

  // Count colors (bucketed for clustering) with edge weighting
  const colors = new Map<
    string,
    { rgb: [number, number, number]; count: number }
  >();
  const centerX = canvas.width / 2;
  const centerY = canvas.height / 2;
  const maxDist = Math.sqrt(centerX * centerX + centerY * centerY);

  for (let i = 0; i < data.length; i += 4) {
    const r = data[i],
      g = data[i + 1],
      b = data[i + 2],
      a = data[i + 3];

    // Skip transparent pixels
    if (a < 128) continue;

    // Basic brightness filter - avoid pure black/white extremes
    const brightness = (r + g + b) / 3;
    if (brightness < 40 || brightness > 240) continue;

    // Check saturation - prefer colors with some saturation
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const saturation = max === 0 ? 0 : (max - min) / max;

    // Skip very desaturated (gray) colors, but allow darker saturated colors
    if (saturation < 0.15) continue;

    // Calculate edge weight (pixels farther from center get more weight)
    const pixelIndex = i / 4;
    const x = pixelIndex % canvas.width;
    const y = Math.floor(pixelIndex / canvas.width);
    const distFromCenter = Math.sqrt((x - centerX) ** 2 + (y - centerY) ** 2);
    const edgeWeight = (distFromCenter / maxDist) ** 1.5; // Power > 1 emphasizes edges more
    const weight = Math.max(1, Math.round(edgeWeight * 3)); // 1-3x weight based on distance

    // Bucket colors for clustering
    const key = `${Math.floor(r / 32)},${Math.floor(g / 32)},${Math.floor(b / 32)}`;
    const entry = colors.get(key);
    if (entry) {
      entry.count += weight;
    } else {
      colors.set(key, { rgb: [r, g, b], count: weight });
    }
  }

  // Find most frequent color that passed our filters
  let max = 0,
    accent: [number, number, number] = [100, 100, 200];
  for (const { rgb, count } of colors.values()) {
    if (count > max) {
      max = count;
      accent = rgb;
    }
  }

  // If no suitable color found, fall back to less strict criteria
  if (max === 0) {
    const fallbackColors = new Map<
      string,
      { rgb: [number, number, number]; count: number }
    >();

    for (let i = 0; i < data.length; i += 4) {
      const r = data[i],
        g = data[i + 1],
        b = data[i + 2],
        a = data[i + 3];
      if (a < 128) continue;

      const brightness = (r + g + b) / 3;
      if (brightness < 40 || brightness > 220) continue;

      const key = `${Math.floor(r / 32)},${Math.floor(g / 32)},${Math.floor(b / 32)}`;
      const entry = fallbackColors.get(key);
      if (entry) {
        entry.count++;
      } else {
        fallbackColors.set(key, { rgb: [r, g, b], count: 1 });
      }
    }

    for (const { rgb, count } of fallbackColors.values()) {
      if (count > max) {
        max = count;
        accent = rgb;
      }
    }
  }

  return accent;
}

// Determine if text should be black or white based on background color
export function getTextColor(backgroundColor: string): "black" | "white" {
  const color = oklch(backgroundColor);

  if (!color || color.l === undefined) return "white";

  // OKLCH lightness threshold: 0.65 is roughly where contrast flips
  // Below 0.65 = use white text
  // Above 0.65 = use black text
  return color.l > 0.7 ? "black" : "white";
}

// Get text colors for entire palette
export function getTextColorsForPalette(
  palette: Record<string, string>,
): Record<string, "black" | "white"> {
  const textColors: Record<string, "black" | "white"> = {};

  Object.entries(palette).forEach(([key, bgColor]) => {
    textColors[key] = getTextColor(bgColor);
  });

  return textColors;
}

// Generate Tailwind palette using OKLCH
export function generateTailwindPalette(
  rgb: [number, number, number],
): Record<string, string> {
  const [r, g, b] = rgb;
  const base = oklch(`rgb(${r}, ${g}, ${b})`);

  if (!base) return {};

  const shades = {
    50: 0.99,
    100: 0.95,
    200: 0.9,
    300: 0.82,
    400: 0.7,
    500: base.l, // base color
    600: base.l * 0.88,
    700: base.l * 0.75,
    800: base.l * 0.62,
    900: base.l * 0.5,
    950: base.l * 0.4,
  };

  const palette: Record<string, string> = {};

  Object.entries(shades).forEach(([shade, lightness]) => {
    // Reduce chroma for very light/dark shades
    let chroma = base.c;
    if (parseInt(shade, 10) <= 100) chroma *= 0.25;
    else if (parseInt(shade, 10) <= 200) chroma *= 0.5;
    else if (parseInt(shade, 10) >= 900) chroma *= 0.7;

    const color = {
      mode: "oklch" as const,
      l: lightness,
      c: chroma,
      h: base.h || 0,
    };
    palette[`accent-${shade}`] = formatCss(color);
  });

  return palette;
}

// All-in-one function
export function updateAccentColor(img: HTMLImageElement) {
  const color = extractAccentColor(img);
  const palette = generateTailwindPalette(color);
  const textColors = getTextColorsForPalette(palette);

  for (const name in palette) {
    document.documentElement.style.setProperty(`--${name}`, palette[name]);

    if (name === "accent-200") {
      document.documentElement.style.setProperty(
        `--text-selected`,
        textColors[name],
      );
    }
  }
}

export function resetAccentColor() {
  const defaultValues: { [key: string]: string } = {
    "accent-50": "--slate-50",
    "accent-100": "--slate-100",
    "accent-200": "--slate-200",
    "accent-300": "--slate-300",
    "accent-400": "--slate-400",
    "accent-500": "--slate-500",
    "accent-600": "--slate-600",
    "accent-700": "--slate-700",
    "accent-800": "--slate-800",
    "accent-900": "--slate-900",
    "accent-950": "--slate-950",
    "text-selected": "--black",
  };

  for (const name in defaultValues) {
    const cssVar = defaultValues[name];
    const value = document.documentElement.style.getPropertyValue(cssVar);
    document.documentElement.style.setProperty(`--${name}`, value);
  }
}
