import { createFileRoute } from "@tanstack/react-router";
import { Trans, useTranslation } from "react-i18next";
import { ColorPicker } from "../../components/ColorPicker";
import {
  SettingsGroup,
  SettingsPage,
  SettingsRow,
} from "../../components/Settings";
import { ThemeSwitcher } from "../../components/ThemeSwitcher";
import { useTheme } from "../../hooks/useTheme";
import { settings, useSetting } from "../../services/settings";
import { updateAccentColor } from "../../utils/updateAccentColor";

export const Route = createFileRoute("/_authenticated/settings/appearance")({
  staticData: { view: "settings" as const },
  component: AppearanceSettings,
});

function AppearanceSettings() {
  const { t } = useTranslation();
  const color = useSetting(settings.baseAccentColor);
  const { theme, setTheme } = useTheme();
  const showArtistArtwork = useSetting(settings.showArtistArtwork);

  return (
    <SettingsPage
      title={t("settings.appearance.title", { defaultValue: "Appearance" })}
      subtitle={t("settings.appearance.summary", {
        defaultValue:
          "These settings are stored locally for this browser only.",
      })}
    >
      <SettingsGroup>
        <SettingsRow
          label={t("settings.appearance.theme", { defaultValue: "Theme" })}
        >
          <ThemeSwitcher value={theme} onChange={setTheme} />
        </SettingsRow>
        <SettingsRow
          label={t("settings.appearance.accentColor", {
            defaultValue: "Accent Color",
          })}
        >
          <ColorPicker value={color} onChange={updateAccentColor} />
        </SettingsRow>
        <SettingsRow
          label={t("settings.artistArtwork.title", {
            defaultValue: "Artist Artwork",
          })}
        >
          <label className="flex items-center gap-2 text-sm @xl:pt-1.5">
            <input
              type="checkbox"
              className="accent-accent-500"
              checked={showArtistArtwork}
              onChange={(e) => settings.showArtistArtwork.set(e.target.checked)}
            />
            <Trans i18nKey="settings.artistArtwork.showInList">
              Show photos in the artist list.
            </Trans>
          </label>
        </SettingsRow>
      </SettingsGroup>
    </SettingsPage>
  );
}
