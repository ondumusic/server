import { type PropsWithChildren, useEffect } from "react";
import { settings, useSetting } from "../services/settings";

function getSystemTheme() {
  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

function applyTheme(newTheme: string) {
  const theme = newTheme === "auto" ? getSystemTheme() : newTheme;
  document.documentElement.setAttribute("data-theme", theme);
}

export function useTheme() {
  const theme = useSetting(settings.theme);
  return { theme, setTheme: settings.theme.set };
}

export const ThemeProvider = ({ children }: PropsWithChildren) => {
  const theme = useSetting(settings.theme);

  useEffect(() => {
    applyTheme(theme);
  }, [theme]);

  useEffect(() => {
    if (theme !== "auto") return;
    const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = () => applyTheme("auto");
    mediaQuery.addEventListener("change", handler);
    return () => mediaQuery.removeEventListener("change", handler);
  }, [theme]);

  return children;
};
