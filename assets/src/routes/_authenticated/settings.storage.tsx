import { createFileRoute } from "@tanstack/react-router";
import { Trans, useTranslation } from "react-i18next";
import {
  SettingsGroup,
  SettingsPage,
  SettingsRow,
} from "../../components/Settings";
import { useDialog } from "../../hooks/useDialog";
import { repo } from "../../library";

export const Route = createFileRoute("/_authenticated/settings/storage")({
  staticData: { view: "settings" as const },
  component: StorageSettings,
});

const resetButtonClassName = [
  "px-3 py-1.5 rounded-md  cursor-pointer",
  "text-sm font-medium text-red-600 dark:text-red-400",
  "ring-1 ring-inset ring-red-600/30 dark:ring-red-400/30 hover:bg-red-500/10",
].join(" ");

function StorageSettings() {
  const { t } = useTranslation();
  const { promptConfirm } = useDialog();

  const handleResetDatabase = async () => {
    const confirmed = await promptConfirm({
      danger: true,
      message: t("promptResetDatabase.message", {
        defaultValue: "Are you sure you want to reset your local database?",
      }),
      confirmMessage: t("promptResetDatabase.confirm", {
        defaultValue: "Reset",
      }),
      cancelMessage: t("promptResetDatabase.cancel", {
        defaultValue: "Cancel",
      }),
    });
    if (!confirmed) return;
    await repo.teardown();
    window.location.reload();
  };

  const handleResetSettings = async () => {
    const confirmed = await promptConfirm({
      danger: true,
      message: t("promptResetSettings.message", {
        defaultValue: "Are you sure you want to reset your local settings?",
      }),
      confirmMessage: t("promptResetSettings.confirm", {
        defaultValue: "Reset",
      }),
      cancelMessage: t("promptResetSettings.cancel", {
        defaultValue: "Cancel",
      }),
    });
    if (!confirmed) return;

    // Not using localStorage.clear because auth token is also in there, so
    // might make sense to move this to a separate settings service or something
    localStorage.removeItem("albumSort");
    localStorage.removeItem("albumSortDir");
    localStorage.removeItem("baseAccentColor");
    localStorage.removeItem("theme");
    localStorage.removeItem("recordPlays");
    location.reload();
  };

  return (
    <SettingsPage
      title={t("settings.storage.title", { defaultValue: "Storage" })}
      subtitle={t("settings.storage.summary", {
        defaultValue: "Sometimes you just need a little reset.",
      })}
    >
      <SettingsGroup>
        <SettingsRow
          label={t("settings.storage.localDatabase", {
            defaultValue: "Local Database",
          })}
          help={t("settings.storage.localDatabaseHelp", {
            defaultValue: "Resets your local IndexedDB and starts a new sync.",
          })}
        >
          <button
            type="button"
            className={resetButtonClassName}
            onClick={handleResetDatabase}
          >
            <Trans i18nKey="settings.storage.resetLocalDatabase">
              Reset Local Database
            </Trans>
          </button>
        </SettingsRow>
        <SettingsRow
          label={t("settings.storage.userSettings", {
            defaultValue: "User Settings",
          })}
          help={t("settings.storage.userSettingsHelp", {
            defaultValue:
              "Resets all the custom settings for this browser session.",
          })}
        >
          <button
            type="button"
            className={resetButtonClassName}
            onClick={handleResetSettings}
          >
            <Trans i18nKey="settings.storage.resetUserSettings">
              Reset User Settings
            </Trans>
          </button>
        </SettingsRow>
      </SettingsGroup>
    </SettingsPage>
  );
}
