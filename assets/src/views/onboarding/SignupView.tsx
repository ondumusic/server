import { Trans, useTranslation } from "react-i18next";
import { Button } from "../../components/form/Button";
import { FormActions } from "../../components/form/FormActions";
import { Input } from "../../components/form/Input";
import { type FormErrors, type FormState, useForm } from "../../hooks/useForm";
import { api } from "../../services/api";
import type { User } from "../../types";
import type { OnboardingStep } from "../../views/OnboardingView";

type SignupFields = {
  username: string | number | null;
  password: string | number | null;
  password_confirmation: string | number | null;
};

interface Request {
  username: string;
  password_confirmation: string;
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

interface Props {
  setOnboardingStep(_nextStep: OnboardingStep): void;
  completeLogin(_user: User, _sessionToken: string): void;
}

export function SignupView({ setOnboardingStep, completeLogin }: Props) {
  const { t } = useTranslation();

  const onSignupSuccess = (response: SuccessResponse) => {
    completeLogin(response.currentUser, response.sessionToken);
    setOnboardingStep("settings");
  };

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

    const response = await api.post<Request, Response>(
      "/auth/signup",
      newState.fields as Request,
    );

    if (response.ok) {
      onSignupSuccess(response);
    } else {
      newState.errors = response.fields;
    }

    return newState;
  };

  const form = useForm<SignupFields>("signupForm", onSubmit);

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
