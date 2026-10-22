import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import { ColorPicker } from "../../components/ColorPicker";
import {
  SettingsGroup,
  SettingsPage,
  SettingsRow,
} from "../../components/Settings";
import { ThemeSwitcher } from "../../components/ThemeSwitcher";
import { useTheme } from "../../hooks/useTheme";
import {
  getAccentColor,
  updateAccentColor,
} from "../../utils/updateAccentColor";

export const Route = createFileRoute("/_authenticated/settings/appearance")({
  staticData: { view: "settings" as const },
  component: AppearanceSettings,
});

function AppearanceSettings() {
  const { t } = useTranslation();
  const [color, setColor] = useState(getAccentColor());
  const { theme, setTheme } = useTheme();

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
          <ColorPicker
            value={color}
            onChange={(newColor) => {
              updateAccentColor(newColor);
              setColor(newColor);
            }}
          />
        </SettingsRow>
      </SettingsGroup>
    </SettingsPage>
  );
}
