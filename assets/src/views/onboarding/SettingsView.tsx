import { Trans, useTranslation } from "react-i18next";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { type FormErrors, type FormState, useForm } from "../../hooks/useForm";
import { api } from "../../services/api";

type SettingFields = {
  music_path: string | null;
};

interface Request {
  music_path: string;
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
            field="music_path"
            label={t("settingsForm.field.music_path", {
              defaultValue: "Music Path",
            })}
            defaultValue="/music"
            required
            autoFocus
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
