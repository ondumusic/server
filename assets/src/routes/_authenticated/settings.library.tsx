import { createFileRoute, useRouter } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { settingApi } from "../../api";
import { Button } from "../../components/form/Button";
import { Input } from "../../components/form/Input";
import {
  SettingsActions,
  SettingsGroup,
  SettingsPage,
} from "../../components/Settings";
import { type FormState, useForm } from "../../hooks/useForm";
import { useToast } from "../../hooks/useToast";
import { useStats } from "../../library";
import type { ScanType } from "../../types";
import { formatStat } from "../../utils/formatStat";

export const Route = createFileRoute("/_authenticated/settings/library")({
  async loader() {
    const settings = await settingApi.getSettings();
    return {
      ...settings,
      pollInterval: String(settings.pollInterval),
    };
  },
  staticData: { view: "settings" as const },
  component: LibrarySettings,
});

type SettingFields = {
  scanType?: ScanType;
  pollInterval?: string;
  stripSortPrefixes?: string[];
};

function LibrarySettings() {
  const { t } = useTranslation();
  const { showToast } = useToast();
  const { data: stats } = useStats();
  const router = useRouter();
  const [currentSettings, setCurrentSettings] = useState<SettingFields>(
    Route.useLoaderData(),
  );

  const onSubmit = async (prevState: FormState, formData: FormData) => {
    const newState: FormState = {
      ...prevState,
      errors: {},
    };

    const response = await settingApi.updateSettings({
      scanType: formData.get("scanType") as ScanType,
      pollInterval: parseInt(
        formData.get("pollInterval") as string,
        10,
      ) as number,
      stripSortPrefixes: formData.getAll("stripSortPrefixes") as string[],
    });
    if (response.ok) {
      setCurrentSettings({
        ...response.settings,
        pollInterval: String(response.settings.pollInterval),
      });
      showToast({
        message: t("toast.librarySettingsSaved", {
          defaultValue: "Updated library settings",
        }),
      });
      newState.ok = true;
      router.invalidate();
    } else {
      newState.errors = response.fields;
      newState.ok = false;
    }

    return newState;
  };

  const form = useForm<SettingFields>(
    "settingsForm",
    onSubmit,
    currentSettings,
    {
      horizontal: true,
    },
  );

  const summary = [
    t("settings.library.artistCount", {
      defaultValue: "{{formattedCount}} artists",
      count: stats?.artists ?? 0,
      formattedCount: formatStat(stats?.artists ?? 0),
    }),
    t("settings.library.albumCount", {
      defaultValue: "{{formattedCount}} albums",
      count: stats?.albums ?? 0,
      formattedCount: formatStat(stats?.albums ?? 0),
    }),
    t("settings.library.trackCount", {
      defaultValue: "{{formattedCount}} tracks",
      count: stats?.tracks ?? 0,
      formattedCount: formatStat(stats?.tracks ?? 0),
    }),
    t("settings.library.playlistCount", {
      defaultValue: "{{formattedCount}} playlists",
      count: stats?.playlists ?? 0,
      formattedCount: formatStat(stats?.playlists ?? 0),
    }),
  ];

  return (
    <SettingsPage
      title={t("settings.library.title", { defaultValue: "Library" })}
      subtitle={summary.join(" · ")}
    >
      <form key={form.key} action={form.action}>
        <SettingsGroup
          title={t("settings.library.scanning", { defaultValue: "Scanning" })}
        >
          <Input<SettingFields>
            form={form}
            type="select"
            field="scanType"
            label={t("settingsForm.field.scanType", {
              defaultValue: "Scan Type",
            })}
            options={{
              quick: t("scanType.quick", {
                defaultValue: "Quick Scan (skips existing)",
              }),
              full: t("scanType.full", {
                defaultValue: "Full Scan (includes existing files)",
              }),
            }}
            help={t("settingsForm.help.scanType", {
              defaultValue:
                "In general, a quick scan is recommended as it is much faster.",
            })}
            required
          />

          <Input<SettingFields>
            form={form}
            type="select"
            field="pollInterval"
            label={t("settingsForm.field.pollInterval", {
              defaultValue: "Scan Interval",
            })}
            help={t("settingsForm.help.pollInterval", {
              defaultValue: "How often should we scan for new music?",
            })}
            options={{
              "5": t("pollInterval.5min", {
                defaultValue: "Every 5 minutes",
              }),
              "10": t("pollInterval.10min", {
                defaultValue: "Every 10 minutes",
              }),
              "15": t("pollInterval.15min", {
                defaultValue: "Every 15 minutes",
              }),
              "30": t("pollInterval.30min", {
                defaultValue: "Every half hour",
              }),
              "60": t("pollInterval.60min", {
                defaultValue: "Every hour",
              }),
              "120": t("pollInterval.120min", {
                defaultValue: "Every 2 hours",
              }),
              "180": t("pollInterval.180min", {
                defaultValue: "Every 3 hours",
              }),
              "360": t("pollInterval.360min", {
                defaultValue: "Every 6 hours",
              }),
              "720": t("pollInterval.720min", {
                defaultValue: "Every 12 hours",
              }),
              "1440": t("pollInterval.1440min", {
                defaultValue: "Every 24 hours",
              }),
            }}
            required
          />

          <Input<SettingFields>
            form={form}
            type="token"
            field="stripSortPrefixes"
            label={t("settingsForm.field.stripSortPrefixes", {
              defaultValue: "Sort Prefixes",
            })}
            help={t("settingsForm.help.stripSortPrefixes", {
              defaultValue:
                'A list of prefixes to filter out when sorting, e.g. if you want The Beatles to be sorted as Beatles you would add "the".',
            })}
          />

          <SettingsActions>
            <Button
              disabled={!form.isDirty || form.isPending}
              type="submit"
              style="primary"
            >
              <Trans i18nKey="settings.library.save">Save Changes</Trans>
            </Button>
          </SettingsActions>
        </SettingsGroup>
      </form>
    </SettingsPage>
  );
}
