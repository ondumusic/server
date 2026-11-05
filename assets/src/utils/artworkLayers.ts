import type { CSSProperties } from "react";

export function artworkLayers(urls: string[]): CSSProperties {
  const layers = [
    ...urls.map((url) => `url(${url})`),
    "var(--artwork-placeholder)",
  ];
  return {
    backgroundImage: layers.join(", "),
    backgroundSize: "cover",
    backgroundPosition: "center",
    backgroundRepeat: "no-repeat",
  };
}
