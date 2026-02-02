import { createFileRoute, Navigate } from "@tanstack/react-router";
import { useRef } from "react";
import { Trans, useTranslation } from "react-i18next";
import { client } from "../api";
import { Button } from "../components/form/Button";
import { FormActions } from "../components/form/FormActions";
import { Input } from "../components/form/Input";
import { Panel } from "../components/Panel";
import { useAuth } from "../hooks/useAuth";
import { type FormErrors, type FormState, useForm } from "../hooks/useForm";
import type { User } from "../types";

interface LocationSearch {
  redirect: string;
}

type LoginFields = {
  username: string | number | null;
  password: string | number | null;
};

interface Request {
  username: string;
  password: string;
}

interface ErrorResponse {
  ok: false;
  fields: FormErrors;
}

interface SuccessResponse {
  ok: true;
  currentUser: User;
  sessionToken: string;
}

type Response = ErrorResponse | SuccessResponse;

export const Route = createFileRoute("/login")({
  component: Login,
});

function Login() {
  const { isLoggedIn, completeLogin } = useAuth();
  const { t } = useTranslation();
  const { redirect: redirectTo } = Route.useSearch() as LocationSearch;
  const redirectRef = useRef<string>(redirectTo ?? "/");

  const onLoginSuccess = (response: SuccessResponse) => {
    completeLogin(response.currentUser, response.sessionToken);
  };

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

    const response = await client.post<Request, Response>(
      "/auth/login",
      newState.fields as Request,
    );
    if (response.ok) {
      onLoginSuccess(response);
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
      <Panel>
        <Panel.Header title={t("loginForm.title", { defaultValue: "Login" })} />

        <form action={form.action} className="mt-10 space-y-8">
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
