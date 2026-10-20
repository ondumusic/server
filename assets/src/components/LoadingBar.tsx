import { useTranslation } from "react-i18next";

export function LoadingBar() {
  const { t } = useTranslation();

  return (
    <div
      role="progressbar"
      aria-label={t("loading.text", { defaultValue: "Loading" })}
      className="h-1 rounded-full bg-black/10 dark:bg-white/15 overflow-hidden"
    >
      <div className="h-full w-1/3 rounded-full bg-accent-500 loading-bar" />
    </div>
  );
}
