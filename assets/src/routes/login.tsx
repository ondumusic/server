import { createFileRoute, Navigate } from "@tanstack/react-router";
import { useRef } from "react";
import { Trans, useTranslation } from "react-i18next";
import { authApi } from "../api";
import { Button } from "../components/form/Button";
import { FormActions } from "../components/form/FormActions";
import { Input } from "../components/form/Input";
import { Panel } from "../components/Panel";
import { useAuth } from "../hooks/useAuth";
import { type FormState, useForm } from "../hooks/useForm";

interface LocationSearch {
  redirect: string;
}

type LoginFields = {
  username?: string;
  password?: string;
};

export const Route = createFileRoute("/login")({
  component: Login,
});

function Login() {
  const { isLoggedIn, completeLogin } = useAuth();
  const { t } = useTranslation();
  const { redirect: redirectTo } = Route.useSearch() as LocationSearch;
  const redirectRef = useRef<string>(redirectTo ?? "/");

  const onSubmit = async (
    prevState: FormState<LoginFields>,
    formData: FormData,
  ) => {
    const newState: FormState<LoginFields> = {
      ...prevState,
      fields: {
        username: formData.get("username") as string,
        password: formData.get("password") as string,
      },
      errors: {},
    };

    const response = await authApi.login(
      newState.fields.username,
      newState.fields.password,
    );

    if (response.ok) {
      completeLogin(response.currentUser, response.sessionToken);
    } else {
      newState.errors = response.fields;
    }

    return newState;
  };

  const form = useForm<LoginFields>("loginForm", onSubmit);

  if (isLoggedIn) {
    return <Navigate to={redirectRef?.current ?? "/"} replace />;
  }

  return (
    <div className="h-full content-center">
      <Panel
        size="small"
        title={t("loginForm.title", { defaultValue: "Login" })}
      >
        <form action={form.action} className="space-y-8 pt-8 py-4 px-6">
          <Input<LoginFields>
            form={form}
            type="text"
            field="username"
            label={t("loginForm.field.username", { defaultValue: "Username" })}
            required
            autoFocus
          />

          <Input<LoginFields>
            form={form}
            type="password"
            field="password"
            defaultValue=""
            label={t("loginForm.field.password", { defaultValue: "Password" })}
            required
          />

          <FormActions>
            <Button disabled={form.isPending} type="submit">
              <Trans i18nKey="loginForm.button.login">Login</Trans>
            </Button>
          </FormActions>
        </form>
      </Panel>
    </div>
  );
}
