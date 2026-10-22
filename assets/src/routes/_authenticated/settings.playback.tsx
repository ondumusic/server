import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import {
  SettingsGroup,
  SettingsPage,
  SettingsRow,
} from "../../components/Settings";
import { playRecorder } from "../../services/plays";

export const Route = createFileRoute("/_authenticated/settings/playback")({
  staticData: { view: "settings" as const },
  component: PlaybackSettings,
});

function PlaybackSettings() {
  const { t } = useTranslation();
  const [recordPlays, setRecordPlays] = useState(playRecorder.enabled);

  return (
    <SettingsPage
      title={t("settings.playback.title", { defaultValue: "Playback" })}
      subtitle={t("settings.playback.summary", {
        defaultValue:
          "These settings are stored locally for this browser only.",
      })}
    >
      <SettingsGroup>
        <SettingsRow
          label={t("settings.playHistory.title", {
            defaultValue: "Play History",
          })}
          help={t("settings.playHistory.summary", {
            defaultValue:
              "Record and sync your play history to your Ondu Server.",
          })}
        >
          <label className="flex items-center gap-2 text-sm @xl:pt-1.5">
            <input
              type="checkbox"
              className="accent-accent-500"
              checked={recordPlays}
              onChange={(e) => {
                playRecorder.enabled = e.target.checked;
                setRecordPlays(e.target.checked);
              }}
            />
            <Trans i18nKey="settings.playHistory.recordInBrowser">
              Yes, record and sync play history.
            </Trans>
          </label>
        </SettingsRow>
      </SettingsGroup>
    </SettingsPage>
  );
}
