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
  const defaultResult: [number, number, number] = [100, 100, 100];
  if (!ctx) return defaultResult;

  // Scale down for performance
  const scale = 0.1;
  canvas.width = img.width * scale;
  canvas.height = img.height * scale;

  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;

  // First pass: count ALL colors (with edge weighting) before filtering
  const allColors = new Map<
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

    if (a < 128) continue;

    // Calculate saturation for this pixel
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const saturation = max === 0 ? 0 : (max - min) / max;

    // Calculate edge weight
    const pixelIndex = i / 4;
    const x = pixelIndex % canvas.width;
    const y = Math.floor(pixelIndex / canvas.width);
    const distFromCenter = Math.sqrt((x - centerX) ** 2 + (y - centerY) ** 2);
    const edgeWeight = (distFromCenter / maxDist) ** 1.5;

    // Boost weight for saturated colors (accent colors should be colorful)
    const saturationBoost = saturation > 0.3 ? 5 : 1;
    const weight = Math.max(1, Math.round(edgeWeight * 3 * saturationBoost));

    const key = `${Math.floor(r / 16)},${Math.floor(g / 16)},${Math.floor(b / 16)}`;
    const entry = allColors.get(key);
    if (entry) {
      entry.count += weight;
    } else {
      allColors.set(key, { rgb: [r, g, b], count: weight });
    }
  }

  // Sort by frequency and try to find a good accent color
  const sortedColors = Array.from(allColors.values()).sort(
    (a, b) => b.count - a.count,
  );

  // Check if image is predominantly grayscale
  const totalCount = sortedColors.reduce((sum, c) => sum + c.count, 0);
  let saturatedCount = 0;

  for (const { rgb, count } of sortedColors) {
    const max = Math.max(...rgb);
    const min = Math.min(...rgb);
    const saturation = max === 0 ? 0 : (max - min) / max;

    if (saturation > 0.2) {
      saturatedCount += count;
    }
  }

  const saturatedPercentage = saturatedCount / totalCount;

  // If less than 10% of the image is colorful, return a neutral gray
  if (saturatedPercentage < 0.15) {
    return [128, 128, 128]; // Mid-gray for neutral palette
  }

  // Try top 20 colors to find a good accent (increased from implicit top-all)
  for (const { rgb } of sortedColors.slice(0, 20)) {
    const [r, g, b] = rgb;

    // Basic brightness filter - avoid only pure black/white extremes
    const brightness = (r + g + b) / 3;
    if (brightness < 30 || brightness > 245) continue;

    // Check saturation - require actual color, not gray
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const saturation = max === 0 ? 0 : (max - min) / max;

    // Require meaningful saturation to avoid grays
    if (saturation < 0.2) continue;

    // This color passes our filters and is most dominant - use it
    return rgb;
  }

  // Fallback: if no color passes filters, take the most dominant color regardless
  if (sortedColors.length > 0) {
    return sortedColors[0].rgb;
  }

  return defaultResult;
}

// Generate Tailwind palette using OKLCH
function generateTailwindPalette(
  rgb: [number, number, number],
): Record<string, string> {
  const [r, g, b] = rgb;
  const base = oklch(`rgb(${r}, ${g}, ${b})`);

  if (!base) return {};

  // Normalize base lightness to a standard value (0.55) for 500 shade
  // This prevents issues with very light colors like yellow
  const normalizedBase = { ...base, l: 0.55 };

  const shades = {
    50: 0.98,
    100: 0.95,
    200: 0.9,
    300: 0.82,
    400: 0.7,
    500: 0.55, // normalized base
    600: 0.45,
    700: 0.38,
    800: 0.3,
    900: 0.23,
    950: 0.18,
  };

  const palette: Record<string, string> = {};

  Object.entries(shades).forEach(([shade, lightness]) => {
    // Reduce chroma for very light/dark shades
    let chroma = normalizedBase.c;
    if (parseInt(shade, 10) <= 100) chroma *= 0.5;
    else if (parseInt(shade, 10) <= 200) chroma *= 0.7;
    else if (parseInt(shade, 10) >= 900) chroma *= 0.9;

    const color = {
      mode: "oklch" as const,
      l: lightness,
      c: chroma,
      h: normalizedBase.h || 0,
    };
    palette[`accent-${shade}`] = formatCss(color);
  });

  return palette;
}

// Determine if text should be black or white based on background color
function getTextColor(backgroundColor: string): "black" | "white" {
  const color = oklch(backgroundColor);

  if (!color || color.l === undefined) return "white";

  // OKLCH lightness threshold: 0.65 is roughly where contrast flips
  // Below 0.65 = use white text
  // Above 0.65 = use black text
  return color.l > 0.65 ? "black" : "white";
}

// Get text colors for entire palette
function getTextColorsForPalette(
  palette: Record<string, string>,
): Record<string, "black" | "white"> {
  const textColors: Record<string, "black" | "white"> = {};

  Object.entries(palette).forEach(([key, bgColor]) => {
    textColors[key] = getTextColor(bgColor);
  });

  return textColors;
}

export function updateAccentColor(img: HTMLImageElement) {
  const color = extractAccentColor(img);
  const palette = generateTailwindPalette(color);
  const textColors = getTextColorsForPalette(palette);
  const root = document.documentElement;

  for (const name in palette) {
    root.style.setProperty(`--${name}`, palette[name]);

    if (name === "accent-200") {
      root.style.setProperty(`--text-selected`, textColors[name]);
    }
  }

  const themeColor = root.style.getPropertyValue("--accent-50");
  const themeTags = root.querySelectorAll("meta[name=theme-color]");
  for (const tag of themeTags) {
    tag.setAttribute("content", themeColor);
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
