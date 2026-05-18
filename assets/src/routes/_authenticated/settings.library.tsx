import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { settingApi } from "../../api";
import { Button } from "../../components/form/Button";
import { Input } from "../../components/form/Input";
import { type FormState, useForm } from "../../hooks/useForm";
import { useToast } from "../../hooks/useToast";
import type { ScanType, Settings } from "../../types";

export const Route = createFileRoute("/_authenticated/settings/library")({
  async loader() {
    return await settingApi.getSettings();
  },
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

type SettingFields = {
  musicPath?: string;
  scanType?: ScanType;
  pollInterval?: number;
};

function SettingsLayout() {
  const { t } = useTranslation();
  const { showToast } = useToast();
  const [currentSettings, setCurrentSettings] = useState<Settings>(
    Route.useLoaderData(),
  );

  const onSubmit = async (
    prevState: FormState<SettingFields>,
    formData: FormData,
  ) => {
    const newState: FormState<SettingFields> = {
      ...prevState,
      fields: {
        scanType: formData.get("scanType") as ScanType,
        pollInterval: parseInt(
          formData.get("pollInterval") as string,
          10,
        ) as number,
      },
      errors: {},
    };

    const response = await settingApi.updateSettings(newState.fields);
    if (response.ok) {
      setCurrentSettings(response.settings);
      showToast({
        message: t("toast.librarySettingsSaved", {
          defaultValue: "Updated library settings",
        }),
      });
    } else {
      newState.errors = response.fields;
    }

    return newState;
  };

  const form = useForm<SettingFields>("settingsForm", onSubmit, {
    horizontal: true,
  });

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
        <form action={form.action} className="space-y-8">
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
            defaultValue={currentSettings.scanType}
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
            defaultValue={String(currentSettings.pollInterval)}
            required
          />

          <div className="w-[50%] ml-[26%]">
            <Button disabled={form.isPending} type="submit" style="primary">
              <Trans i18nKey="settings.library.save">Save Changes</Trans>
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
