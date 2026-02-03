import { createFileRoute, Navigate } from "@tanstack/react-router";
import { Trans, useTranslation } from "react-i18next";
import { authApi } from "../../api";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { useAuth } from "../../hooks/useAuth";
import { type FormState, useForm } from "../../hooks/useForm";

type SignupFields = {
  username?: string;
  password?: string;
  password_confirmation?: string;
};

export const Route = createFileRoute("/onboarding/user")({
  component: UserComponent,
});

export function UserComponent() {
  const { t } = useTranslation();
  const { isLoggedIn, completeLogin } = useAuth();
  const { onboarding } = Route.useRouteContext();

  const onSubmit = async (
    prevState: FormState<SignupFields>,
    formData: FormData,
  ) => {
    const newState: FormState<SignupFields> = {
      ...prevState,
      fields: {
        username: formData.get("username") as string,
        password: formData.get("password") as string,
        password_confirmation: formData.get("password_confirmation") as string,
      },
      errors: {},
    };

    const response = await authApi.signup(
      newState.fields.username,
      newState.fields.password,
      newState.fields.password_confirmation,
    );

    if (response.ok) {
      completeLogin(response.currentUser, response.sessionToken);
      onboarding.setStep("settings");
    } else {
      newState.errors = response.fields;
    }

    return newState;
  };

  const form = useForm<SignupFields>("signupForm", onSubmit);

  if (isLoggedIn) {
    return <Navigate to="/onboarding/settings" />;
  }

  return (
    <div className="h-full content-center">
      <div className="mx-auto max-w-md rounded-md p-6 shadow-md bg-white">
        <header className="text-center">
          <div>
            <h1 className="text-lg font-semibold leading-8 text-zinc-800">
              <Trans i18nKey="signupForm.title">Setup your Account</Trans>
            </h1>
          </div>
        </header>

        <form action={form.action} className="mt-10 space-y-8">
          <Input<SignupFields>
            form={form}
            type="text"
            field="username"
            label={t("signupForm.field.username", { defaultValue: "Username" })}
            required
            autoFocus
          />

          <Input<SignupFields>
            form={form}
            type="password"
            field="password"
            defaultValue=""
            label={t("signupForm.field.password", { defaultValue: "Password" })}
            required
          />

          <Input<SignupFields>
            form={form}
            type="password"
            field="password_confirmation"
            defaultValue=""
            label={t("signupForm.field.password_confirmation", {
              defaultValue: "Confirm Password",
            })}
            required
          />

          <FormActions>
            <Button disabled={form.isPending} type="submit">
              <Trans i18nKey="signupForm.button.login">Signup</Trans>
            </Button>
          </FormActions>
        </form>
      </div>
    </div>
  );
}
