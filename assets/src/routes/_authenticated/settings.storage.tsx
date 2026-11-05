import { createFileRoute } from "@tanstack/react-router";
import { Trans, useTranslation } from "react-i18next";
import {
  SettingsGroup,
  SettingsPage,
  SettingsRow,
} from "../../components/Settings";
import { useDialog } from "../../hooks/useDialog";
import { repo, sync } from "../../library";
import { settings, useSetting } from "../../services/settings";

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
  const preloadArtwork = useSetting(settings.preloadArtwork);

  const handlePreloadArtwork = (enabled: boolean) => {
    settings.preloadArtwork.set(enabled);
    if (enabled) sync.prewarmAll();
  };

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

    settings.reset();
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
          label={t("settings.storage.preloadArtwork", {
            defaultValue: "Artwork Preloading",
          })}
          help={t("settings.storage.preloadArtworkHelp", {
            defaultValue:
              "When enabled this will preload album and artist thumbnails which makes everything feel more instant. It does cost more bandwidth and storage up front.",
          })}
        >
          <label className="flex items-center gap-2 text-sm @xl:pt-1.5">
            <input
              type="checkbox"
              className="accent-accent-500"
              checked={preloadArtwork === true}
              onChange={(e) => handlePreloadArtwork(e.target.checked)}
            />
            <Trans i18nKey="settings.storage.preloadArtworkInBrowser">
              Yes, preload artwork in this browser.
            </Trans>
          </label>
        </SettingsRow>
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
