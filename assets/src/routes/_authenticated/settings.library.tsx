import { createFileRoute, useRouter } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { settingApi } from "../../api";
import { Button } from "../../components/form/Button";
import { Input } from "../../components/form/Input";
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

  return (
    <div className="h-full mx-4 lg:mx-8">
      <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 mb-8 @md:border-b border-panel-fg-divider">
        <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
          <Trans i18nKey="settings.library.title">Library</Trans>
        </h1>
        <span className="text-sm text-panel-fg-muted">
          <Trans i18nKey="settings.library.subtitle">
            Change your music library settings
          </Trans>
        </span>
      </header>

      <div className="space-y-16">
        <div className="grid grid-cols-4 gap-4">
          <div className="border rounded-md shadow-md bg-white/70 border-white/90 dark:border-white/30 dark:bg-black/20 p-4">
            <h4 className="uppercase text-xs text-muted">
              <Trans i18nKey="stats.artists">Artists</Trans>
            </h4>
            <span className="text-2xl">{formatStat(stats?.artists ?? 0)}</span>
          </div>

          <div className="border rounded-md shadow-md bg-white/70 border-white/90 dark:border-white/30 dark:bg-black/20 p-4">
            <h4 className="uppercase text-xs text-muted">
              <Trans i18nKey="stats.albums">Albums</Trans>
            </h4>
            <span className="text-2xl">{formatStat(stats?.albums ?? 0)}</span>
          </div>

          <div className="border rounded-md shadow-md bg-white/70 border-white/90 dark:border-white/30 dark:bg-black/20 p-4">
            <h4 className="uppercase text-xs text-muted">
              <Trans i18nKey="stats.tracks">Tracks</Trans>
            </h4>
            <span className="text-2xl">{formatStat(stats?.tracks ?? 0)}</span>
          </div>

          <div className="border rounded-md shadow-md bg-white/70 border-white/90 dark:border-white/30 dark:bg-black/20 p-4">
            <h4 className="uppercase text-xs text-muted">
              <Trans i18nKey="stats.playlists">Playlists</Trans>
            </h4>
            <span className="text-2xl">
              {formatStat(stats?.playlists ?? 0)}
            </span>
          </div>
        </div>

        <form key={form.key} action={form.action} className="space-y-8">
          <Input<SettingFields>
            form={form}
            type="select"
            field="scanType"
            label={t("settingsForm.field.scanType", {
              defaultValue: "Scan Type",
            })}
            options={{
              quick: "Quick Scan (skips existing)",
              full: "Full Scan (includes existing files)",
            }}
            help={t("settingsForm.help.scanType", {
              defaultValue:
                "In general a quick scan is recommended as it is much faster.",
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
                defaultValue: "Every 2 hour2",
              }),
              "180": t("pollInterval.180min", {
                defaultValue: "Every 3 hour2",
              }),
              "360": t("pollInterval.360min", {
                defaultValue: "Every 6 hour2",
              }),
              "720": t("pollInterval.720min", {
                defaultValue: "Every 12 hour2",
              }),
              "1440": t("pollInterval.1440min", {
                defaultValue: "Every 24 hour2",
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

          <div className="w-[50%] ml-[26%]">
            <Button
              disabled={!form.isDirty || form.isPending}
              type="submit"
              style="primary"
            >
              <Trans i18nKey="settings.library.save">Save Changes</Trans>
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
