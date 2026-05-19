import { createFileRoute } from "@tanstack/react-router";
import { type PropsWithChildren, useState } from "react";
import { Trans } from "react-i18next";
import { ColorPicker } from "../../components/ColorPicker";
import { ThemeSwitcher } from "../../components/ThemeSwitcher";
import { useDialog } from "../../hooks/useDialog";
import { useTheme } from "../../hooks/useTheme";
import i18next from "../../i18next";
import { repo } from "../../library";
import {
  getAccentColor,
  updateAccentColor,
} from "../../utils/updateAccentColor";

export const Route = createFileRoute("/_authenticated/settings/")({
  staticData: { view: "settings" as const },
  component: GeneralSettings,
});

const Section = ({
  children,
  title,
  subtitle,
}: PropsWithChildren<{
  title: string;
  subtitle?: string;
}>) => (
  <div>
    <div className="mb-6">
      <h2 className="font-semibold text-lg">{title}</h2>
      {subtitle && <p className="text-muted text-sm">{subtitle}</p>}
    </div>
    <div className="space-y-8">{children}</div>
  </div>
);

const Setting = ({
  children,
  label,
}: PropsWithChildren<{
  label: string;
  help?: string;
}>) => (
  <div className="grid grid-cols-8 gap-6">
    <div className="col-span-2 text-sm">
      <h3 className="font-medium">{label}</h3>
    </div>
    <div className="col-span-5">{children}</div>
  </div>
);

function GeneralSettings() {
  const [color, setColor] = useState(getAccentColor());
  const { theme, setTheme } = useTheme();
  const { promptConfirm } = useDialog();

  const handleResetDatabase = async () => {
    const confirmed = await promptConfirm({
      danger: true,
      message: "Are you sure you want to reset your local database?",
      confirmMessage: "Reset",
      cancelMessage: "Cancel",
    });
    if (!confirmed) return;
    await repo.teardown();
    location.reload();
  };

  const handleResetSettings = async () => {
    const confirmed = await promptConfirm({
      danger: true,
      message: "Are you sure you want to reset your local settings?",
      confirmMessage: "Reset",
      cancelMessage: "Cancel",
    });
    if (!confirmed) return;

    // Not using localStorage.clear because auth token is also in there, so
    // might make sense to move this to a separate settings service or something
    localStorage.removeItem("albumSort");
    localStorage.removeItem("albumSortDir");
    localStorage.removeItem("baseAccentColor");
    localStorage.removeItem("theme");
    location.reload();
  };

  return (
    <div className="h-full mx-4 lg:mx-8">
      <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 mb-8 @md:border-b border-panel-fg-divider">
        <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
          <Trans i18nKey="settings.general.title">General</Trans>
        </h1>
        <span className="text-sm text-panel-fg-muted">
          <Trans i18nKey="settings.general.subtitle">
            Change user preferences
          </Trans>
        </span>
      </header>

      <div className="space-y-16">
        <Section
          title={i18next.t("settings.appearance.title", {
            defaultValue: "Appearance",
          })}
          subtitle={i18next.t("settings.appearance.summary", {
            defaultValue:
              "These settings are stored locally for this browser only.",
          })}
        >
          <Setting
            label={i18next.t("settings.appearance.theme", {
              defaultValue: "Theme",
            })}
          >
            <ThemeSwitcher value={theme} onChange={setTheme} />
          </Setting>
          <Setting
            label={i18next.t("settings.appearance.accentColor", {
              defaultValue: "Accent Colour",
            })}
          >
            <ColorPicker
              value={color}
              onChange={(newColor) => {
                updateAccentColor(newColor);
                setColor(newColor);
              }}
            />
          </Setting>
        </Section>

        <Section
          title={i18next.t("settings.maintenance.title", {
            defaultValue: "Maintenance",
          })}
          subtitle={i18next.t("settings.maintenance.summary", {
            defaultValue: "Sometimes you just need a little reset.",
          })}
        >
          <Setting label="Reset Options">
            <div className="flex flex-col gap-4">
              <button
                type="button"
                className="bg-red-400 hover:bg-red-500 border border-red-600 dark:border-red-400 cursor-pointer py-1.5 px-2 text-sm rounded-md shadow-md text-white"
                onClick={handleResetDatabase}
              >
                <Trans i18nKey="settings.general.resetLocalDatabase">
                  Reset Local Database
                </Trans>
              </button>

              <button
                type="button"
                className="bg-red-400 hover:bg-red-500 border border-red-600 dark:border-red-400 cursor-pointer py-1.5 px-2 text-sm rounded-md shadow-md text-white"
                onClick={handleResetSettings}
              >
                <Trans i18nKey="settings.general.resetUserSettings">
                  Reset User Settings
                </Trans>
              </button>
            </div>
          </Setting>
        </Section>
      </div>
    </div>
  );
}
