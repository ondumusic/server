import { Trans, useTranslation } from "react-i18next";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { type FormErrors, type FormState, useForm } from "../../hooks/useForm";
import { api } from "../../services/api";

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

interface Props {
  completeOnboarding(): void;
}

export function SettingsView({ completeOnboarding }: Props) {
  const { t } = useTranslation();

  const onSuccess = (_response: SuccessResponse) => {
    completeOnboarding();
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

    const response = await api.post<Request, Response>(
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

  return (
    <div className="h-full content-center bg-stone-50">
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
              defaultValue: "Music Path",
            })}
            defaultValue="/music"
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
              quick: "Quick Scan (skip existing)",
              full: "Full Scan (includes existing files)",
            }}
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
            options={{
              "5": "Every 5 minutes",
              "10": "Every 10 minutes",
              "15": "Every 15 minutes",
              "20": "Every 20 minutes",
              "30": "Every half hour",
              "60": "Every hour",
              "120": "Every 2 hours",
              "180": "Every 3 hours",
              "360": "Every 6 hours",
              "720": "Every 12 hours",
              "1440": "Every 24 hours",
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
