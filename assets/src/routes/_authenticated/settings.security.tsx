import { createFileRoute } from "@tanstack/react-router";
import { Trans, useTranslation } from "react-i18next";
import { userApi } from "../../api";
import { Button } from "../../components/form/Button";
import { Input } from "../../components/form/Input";
import { type FormState, useForm } from "../../hooks/useForm";
import { useToast } from "../../hooks/useToast";

export const Route = createFileRoute("/_authenticated/settings/security")({
  staticData: { view: "settings" as const },
  component: SecuritySettings,
});

type PasswordFields = {
  password?: string;
  currentPassword?: string;
  passwordConfirmation?: string;
};

function SecuritySettings() {
  const { t } = useTranslation();
  const { showToast } = useToast();

  const onSubmit = async (prevState: FormState, formData: FormData) => {
    const newState: FormState = {
      ...prevState,
      errors: {},
    };

    const response = await userApi.updatePassword({
      password: formData.get("password") as string,
      passwordConfirmation: formData.get("passwordConfirmation") as string,
      currentPassword: formData.get("currentPassword") as string,
    });
    if (response.ok) {
      showToast({
        message: t("toast.updatedPassword", {
          defaultValue: "Updated your password",
        }),
      });
      newState.ok = true;
    } else {
      newState.errors = response.fields;
      newState.ok = false;
    }

    return newState;
  };

  const form = useForm<PasswordFields>(
    "passwordForm",
    onSubmit,
    {},
    {
      horizontal: true,
    },
  );

  return (
    <div className="h-full mx-4 lg:mx-8">
      <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 mb-8 @md:border-b border-panel-fg-divider">
        <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
          <Trans i18nKey="settings.security.title">Security</Trans>
        </h1>
        <span className="text-sm text-panel-fg-muted">
          <Trans i18nKey="settings.security.subtitle">
            Change your password
          </Trans>
        </span>
      </header>

      <div className="space-y-16">
        <form key={form.key} action={form.action} className="space-y-8">
          <Input<PasswordFields>
            form={form}
            type="password"
            field="password"
            label={t("passwordForm.field.password", {
              defaultValue: "New Password",
            })}
            required
          />

          <Input<PasswordFields>
            form={form}
            type="password"
            field="passwordConfirmation"
            label={t("passwordForm.field.passwordConfirmation", {
              defaultValue: "Confirm Password",
            })}
            required
          />

          <Input<PasswordFields>
            form={form}
            type="password"
            field="currentPassword"
            label={t("passwordForm.field.currentPassword", {
              defaultValue: "Current Password",
            })}
            required
          />

          <div className="w-[50%] ml-[26%]">
            <Button
              disabled={!form.isDirty || form.isPending}
              type="submit"
              style="primary"
            >
              <Trans i18nKey="settings.password.save">Update Password</Trans>
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
