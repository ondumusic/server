import { Trans, useTranslation } from "react-i18next";
import { type Location, useLocation, useNavigate } from "react-router";
import { Button } from "../components/form/Button";
import { FormActions } from "../components/form/FormActions";
import { Input } from "../components/form/Input";
import { type FormState, useForm } from "../hooks/useForm";
import { api } from "../services/api";

interface LocationState {
  redirectTo: Location;
}

type LoginFields = {
  username: string | number | null;
  password: string | number | null;
};

interface LoginResponse {
  sessionToken: string;
}

export function LoginView() {
  const navigate = useNavigate();
  const { t } = useTranslation();
  const { state } = useLocation();

  const onLoginSuccess = (response: LoginResponse) => {
    localStorage.sessionToken = response.sessionToken;

    if (state) {
      const { redirectTo } = state as LocationState;
      navigate(`${redirectTo.pathname}${redirectTo.search}`);
    } else {
      navigate(`/`);
    }
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

    const response = await api.post("/auth/login", newState.fields);
    if (response.error) {
      newState.errors = response.fields;
    } else {
      onLoginSuccess(response);
    }

    return newState;
  };

  const form = useForm<LoginFields>("loginForm", onSubmit);

  return (
    <div className="h-full content-center bg-stone-50">
      <div className="mx-auto max-w-md rounded-md p-6 shadow-md bg-white">
        <header className="text-center">
          <div>
            <h1 className="text-lg font-semibold leading-8 text-zinc-800">
              <Trans i18nKey="loginForm.title">Login</Trans>
            </h1>
          </div>
        </header>

        <form action={form.action} className="mt-10 space-y-8">
          <Input<LoginFields>
            form={form}
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
      </div>
    </div>
  );
}
