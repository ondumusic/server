import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { Select } from "../../components/form/Select";
import {
  SettingsGroup,
  SettingsPage,
  SettingsRow,
} from "../../components/Settings";
import { playRecorder } from "../../services/plays";
import { transcoding } from "../../services/transcoding";
import type { ServerInfo } from "../../types";
import { Route as SettingsRoute } from "./settings";

export const Route = createFileRoute("/_authenticated/settings/playback")({
  staticData: { view: "settings" as const },
  component: PlaybackSettings,
});

function PlaybackSettings() {
  const { t } = useTranslation();
  const { presets }: ServerInfo = SettingsRoute.useLoaderData();
  const [recordPlays, setRecordPlays] = useState(playRecorder.enabled);
  const [preset, setPreset] = useState(() => {
    const stored = transcoding.preset;
    const known = presets.some(({ id }) => id === stored);
    if (!known) transcoding.preset = null;
    return known ? stored : null;
  });

  // NOTE: The empty option is to prefer original audio files.
  const presetOptions = {
    "": t("settings.transcoding.original", { defaultValue: "Original" }),
    ...Object.fromEntries(presets.map(({ id, name }) => [id, name])),
  };

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
          label={t("settings.transcoding.title", {
            defaultValue: "Streaming Quality",
          })}
          help={t("settings.transcoding.summary", {
            defaultValue:
              "For example you could use the mobile preset to save on bandwidth.",
          })}
        >
          <div className="max-w-md *:first:mt-0">
            <Select
              name="transcodingPreset"
              value={preset ?? ""}
              options={presetOptions}
              onChange={(value) => {
                transcoding.preset = value || null;
                setPreset(value || null);
              }}
            />
          </div>
        </SettingsRow>

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
