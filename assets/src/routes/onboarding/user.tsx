import { createFileRoute, Navigate } from "@tanstack/react-router";
import { Trans, useTranslation } from "react-i18next";
import { authApi } from "../../api";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { Panel } from "../../components/Panel";
import { useAuth } from "../../hooks/useAuth";
import { type FormState, useForm } from "../../hooks/useForm";

type SignupFields = {
  username?: string;
  password?: string;
  passwordConfirmation?: string;
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
        passwordConfirmation: formData.get("passwordConfirmation") as string,
      },
      errors: {},
    };

    const response = await authApi.signup(
      newState.fields.username,
      newState.fields.password,
      newState.fields.passwordConfirmation,
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
      <Panel
        size="small"
        title={t("signupForm.title", { defaultValue: "Setup your Account" })}
      >
        <form action={form.action} className="space-y-8 pt-8 py-4 px-6">
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
            field="passwordConfirmation"
            defaultValue=""
            label={t("signupForm.field.passwordConfirmation", {
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
      </Panel>
    </div>
  );
}
