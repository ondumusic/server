import { createFileRoute, Navigate } from "@tanstack/react-router";
import { useRef } from "react";
import { Trans, useTranslation } from "react-i18next";
import { authApi } from "../api";
import { AuthLayout } from "../components/AuthLayout";
import { Button } from "../components/form/Button";
import { FormActions } from "../components/form/FormActions";
import { Input } from "../components/form/Input";
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

  const onSubmit = async (prevState: FormState, formData: FormData) => {
    const newState: FormState = {
      ...prevState,
      errors: {},
    };

    const fields = {
      username: formData.get("username") as string,
      password: formData.get("password") as string,
    };

    const response = await authApi.login(fields.username, fields.password);

    if (response.ok) {
      completeLogin(response.currentUser, response.sessionToken);
      newState.ok = true;
    } else {
      newState.errors = response.fields;
      newState.ok = false;
      form.resetFields(["password"]);
    }

    return newState;
  };

  const form = useForm<LoginFields>("loginForm", onSubmit, {});

  if (isLoggedIn) {
    return <Navigate to={redirectRef?.current ?? "/"} replace />;
  }

  return (
    <AuthLayout title={t("loginForm.title", { defaultValue: "Welcome back" })}>
      <form key={form.key} action={form.action} className="space-y-6">
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
          label={t("loginForm.field.password", { defaultValue: "Password" })}
          required
        />

        <FormActions>
          <Button disabled={form.isPending} type="submit">
            <Trans i18nKey="loginForm.button.login">Login</Trans>
          </Button>
        </FormActions>
      </form>
    </AuthLayout>
  );
}
