import { createFileRoute, Navigate, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { settingApi } from "../../api";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { Loading } from "../../components/Loading";
import { Panel } from "../../components/Panel";
import { useAuth } from "../../hooks/useAuth";
import { type FormState, useForm } from "../../hooks/useForm";
import { usePhoenixSocket } from "../../hooks/usePhoenixSocket";

type ScanType = "full" | "quick";

type SettingFields = {
  musicPath?: string;
  scanType?: ScanType;
  pollInterval?: number;
};

export const Route = createFileRoute("/onboarding/settings")({
  component: Settings,
});

export function Settings() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { isLoggedIn } = useAuth();
  const { waitForUpdate } = usePhoenixSocket();
  const { onboarding } = Route.useRouteContext();
  const [showLoader, setShowLoader] = useState<boolean>(false);

  const onSubmit = async (
    prevState: FormState<SettingFields>,
    formData: FormData,
  ) => {
    const newState: FormState<SettingFields> = {
      ...prevState,
      fields: {
        musicPath: formData.get("musicPath") as string,
        scanType: formData.get("scanType") as ScanType,
        pollInterval: parseInt(
          formData.get("pollInterval") as string,
          10,
        ) as number,
      },
      errors: {},
    };

    const response = await settingApi.updateSettings(newState.fields);

    // const response = await client.post<Request, Response>(
    //   "/settings",
    //   newState.fields as Request,
    // );

    if (response.ok) {
      setShowLoader(true);
      onboarding.setStep(null);

      waitForUpdate(() => {
        navigate({ to: "/" });
      });
    } else {
      newState.errors = response.fields;
    }

    return newState;
  };

  const form = useForm<SettingFields>("settingsForm", onSubmit);

  if (!isLoggedIn) {
    return (
      <Navigate to="/login" search={{ redirect: "/onboarding/settings" }} />
    );
  }

  if (!onboarding.step) {
    return <Navigate to="/" />;
  }

  if (showLoader) {
    return (
      <Loading>
        <div className="text-stone-600 text-center text-sm mt-4">
          <Trans i18nKey="onboarding.firstLoadWait">
            Finding your music...
          </Trans>
        </div>
      </Loading>
    );
  }

  return (
    <div className="h-full content-center">
      <Panel
        size="small"
        title={t("settingsForm.title", { defaultValue: "Setup MusicBox" })}
      >
        <p className="mt-4 text-center text-sm leading-6 text-muted">
          <Trans i18nKey="settingsForm.subtitle">
            Fill in the form below to get started.
          </Trans>
        </p>

        <form action={form.action} className="space-y-8 pt-8 py-4 px-6">
          <Input<SettingFields>
            form={form}
            type="text"
            field="musicPath"
            label={t("settingsForm.field.musicPath", {
              defaultValue: "Music Directory",
            })}
            defaultValue="/music"
            help={t("settingsForm.help.musicPath", {
              defaultValue:
                "The absolute path to your music collection. When running in a container (like Docker) it will generally be a volume mapped at /music",
            })}
            required
            autoFocus
          />

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
            defaultValue="quick"
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
            defaultValue="60"
            required
          />

          <FormActions>
            <Button disabled={form.isPending} type="submit">
              <Trans i18nKey="settingsForm.button.save">Continue</Trans>
            </Button>
          </FormActions>
        </form>
      </Panel>
    </div>
  );
}
