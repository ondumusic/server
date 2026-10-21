import { Trans, useTranslation } from "react-i18next";
import { useAuth } from "../hooks/useAuth";
import { AuthLayout } from "./AuthLayout";

// Most of the development time has been backend, web desktop and finally the
// native apps. Mobile web was just low priority, so for now we'll show a
// message saying sorry, and maybe in the future it will be available. Or not,
// not sure who would want to use a lesser experience than the native apps.

export function SmallScreen() {
  const { t } = useTranslation();
  const { logout } = useAuth();

  return (
    <AuthLayout
      title={t("smallScreen.title", {
        defaultValue: "A screen for ants?",
      })}
      subtitle={t("smallScreen.subtitle", {
        defaultValue:
          "Sorry, the web app doesn't support small screens yet. Please try one of the official Ondu apps instead, or open it on a bigger screen.",
      })}
    >
      <a
        href="https://ondumusic.com"
        rel="noreferrer"
        className="block w-full rounded-lg py-2 px-3 text-center text-sm font-semibold leading-6 shadow-md bg-accent-600 hover:bg-accent-700 text-white"
      >
        <Trans i18nKey="smallScreen.openWebsite">Get the apps</Trans>
      </a>

      <button
        type="button"
        onClick={logout}
        className="mt-3 block w-full rounded-lg py-2 px-3 text-center text-sm font-semibold leading-6 cursor-pointer ring-1 ring-inset ring-black/10 dark:ring-white/15 hover:bg-black/5 dark:hover:bg-white/5"
      >
        <Trans i18nKey="smallScreen.logout">Logout</Trans>
      </button>
    </AuthLayout>
  );
}
