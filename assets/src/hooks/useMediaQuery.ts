import { useRef, useSyncExternalStore } from "react";

export function useMediaQuery(query: string) {
  const mediaQuery = useRef(window.matchMedia(query));

  return useSyncExternalStore(
    (callback) => {
      mediaQuery.current.addEventListener("change", callback);
      return () => {
        mediaQuery.current.removeEventListener("change", callback);
      };
    },
    () => mediaQuery.current.matches,
  );
}

// Default Tailwind Media Queries Quick Reference:
// sm  40rem (640px)   @media (width >= 40rem) { ... }
// md  48rem (768px)   @media (width >= 48rem) { ... }
// lg  64rem (1024px)  @media (width >= 64rem) { ... }
// xl  80rem (1280px)  @media (width >= 80rem) { ... }
// 2xl 96rem (1536px)  @media (width >= 96rem) { ... }
