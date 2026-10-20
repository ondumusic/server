import { createFileRoute, Navigate, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { settingApi } from "../../api";
import { AuthLayout } from "../../components/AuthLayout";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { ArrowRightIcon } from "../../components/icons/ArrowRightIcon";
import { Loading } from "../../components/Loading";
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

  const onSubmit = async (prevState: FormState, formData: FormData) => {
    const newState: FormState = {
      ...prevState,
      errors: {},
    };

    const fields = {
      musicPath: formData.get("musicPath") as string,
      scanType: formData.get("scanType") as ScanType,
      pollInterval: parseInt(
        formData.get("pollInterval") as string,
        10,
      ) as number,
    };

    const response = await settingApi.updateSettings(fields);

    // const response = await client.post<Request, Response>(
    //   "/settings",
    //   newState.fields as Request,
    // );

    if (response.ok) {
      setShowLoader(true);
      onboarding.setStep(null);
      newState.ok = true;

      waitForUpdate(() => {
        navigate({ to: "/" });
      });
    } else {
      newState.ok = false;
      newState.errors = response.fields;
    }

    return newState;
  };

  const form = useForm<SettingFields>("settingsForm", onSubmit, {
    musicPath: "/music",
    scanType: "quick",
    pollInterval: 60,
  });

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
    <AuthLayout
      title={t("settingsForm.title", { defaultValue: "Add your music" })}
      subtitle={t("settingsForm.subtitle", {
        defaultValue: "Tell Ondu where your music lives.",
      })}
      onboardingStep="settings"
    >
      <form key={form.key} action={form.action} className="space-y-6">
        <Input<SettingFields>
          form={form}
          type="text"
          field="musicPath"
          label={t("settingsForm.field.musicPath", {
            defaultValue: "Music Directory",
          })}
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

        <FormActions>
          <Button disabled={form.isPending} type="submit">
            <span className="relative block px-6">
              <Trans i18nKey="settingsForm.button.startScan">
                Start scanning
              </Trans>
              <ArrowRightIcon
                className="absolute right-0 top-1/2 -translate-y-1/2 size-4"
                title=""
              />
            </span>
          </Button>
        </FormActions>
      </form>
    </AuthLayout>
  );
}
