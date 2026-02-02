import { createFileRoute, Navigate, useNavigate } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { client } from "../../api";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { Loading } from "../../components/Loading";
import { useAuth } from "../../hooks/useAuth";
import { type FormErrors, type FormState, useForm } from "../../hooks/useForm";
import { usePhoenixSocket } from "../../hooks/usePhoenixSocket";

type ScanType = "full" | "quick";

type SettingFields = {
  music_path: string | null;
  scan_type: ScanType;
  poll_interval: number | null;
};

interface Request {
  music_path: string;
  scan_type: ScanType;
  poll_interval: number;
}

interface ErrorResponse {
  ok: false;
  fields: FormErrors;
}

interface SuccessResponse {
  ok: true;
}

type Response = ErrorResponse | SuccessResponse;

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

  const onSuccess = (_response: SuccessResponse) => {
    setShowLoader(true);
    onboarding.setStep(null);

    waitForUpdate(() => {
      navigate({ to: "/" });
    });
  };

  const onSubmit = async (
    prevState: FormState<SettingFields>,
    formData: FormData,
  ) => {
    const newState: FormState<SettingFields> = {
      ...prevState,
      fields: {
        music_path: formData.get("music_path") as string,
        scan_type: formData.get("scan_type") as ScanType,
        poll_interval: parseInt(
          formData.get("poll_interval") as string,
          10,
        ) as number,
      },
      errors: {},
    };

    const response = await client.post<Request, Response>(
      "/settings",
      newState.fields as Request,
    );

    if (response.ok) {
      onSuccess(response);
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
      <div className="mx-auto max-w-md rounded-md p-6 shadow-md bg-white">
        <header className="text-center">
          <div>
            <h1 className="text-lg font-semibold leading-8 text-zinc-800">
              <Trans i18nKey="settingsForm.title">Setup MusicBox</Trans>
            </h1>
            <p className="mt-2 text-sm leading-6 text-zinc-600">
              <Trans i18nKey="settingsForm.subtitle">
                Fill in the form below to get started.
              </Trans>
            </p>
          </div>
        </header>

        <form action={form.action} className="mt-10 space-y-8">
          <Input<SettingFields>
            form={form}
            type="text"
            field="music_path"
            label={t("settingsForm.field.music_path", {
              defaultValue: "Music Directory",
            })}
            defaultValue="/music"
            help={t("settingsForm.help.music_path", {
              defaultValue:
                "The absolute path to your music collection. When running in a container (like Docker) it will generally be a volume mapped at /music",
            })}
            required
            autoFocus
          />

          <Input<SettingFields>
            form={form}
            type="select"
            field="scan_type"
            label={t("settingsForm.field.scan_type", {
              defaultValue: "Scan Type",
            })}
            options={{
              quick: "Quick Scan (skips existing)",
              full: "Full Scan (includes existing files)",
            }}
            help={t("settingsForm.help.scan_type", {
              defaultValue:
                "In general a quick scan is recommended as it is much faster.",
            })}
            defaultValue="quick"
            required
          />

          <Input<SettingFields>
            form={form}
            type="select"
            field="poll_interval"
            label={t("settingsForm.field.poll_interval", {
              defaultValue: "Scan Interval",
            })}
            help={t("settingsForm.help.poll_interval", {
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
                defaultValue: "Every 2 hour",
              }),
              "180": t("pollInterval.180min", {
                defaultValue: "Every 3 hour",
              }),
              "360": t("pollInterval.360min", {
                defaultValue: "Every 6 hour",
              }),
              "720": t("pollInterval.720min", {
                defaultValue: "Every 12 hour",
              }),
              "1440": t("pollInterval.1440min", {
                defaultValue: "Every 24 hour",
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
      </div>
    </div>
  );
}
