import { type Location, useLocation, useNavigate } from "react-router";
import { Label } from "../components/Label";
import { TextField } from "../components/TextField";
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
    _prevState: FormState<LoginFields>,
    formData: FormData,
  ) => {
    const newState: FormState<LoginFields> = {
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

  const [formState, formAction, isPending] = useForm<LoginFields>(onSubmit);

  return (
    <div className="h-full content-center bg-stone-50">
      <div className="mx-auto max-w-md rounded-md p-6 shadow-md bg-white">
        <header className="text-center">
          <div>
            <h1 className="text-lg font-semibold leading-8 text-zinc-800">
              Login Screen
            </h1>
          </div>
        </header>

        <form action={formAction} className="mt-10 space-y-8">
          <div>
            <Label htmlFor="username" title="Username" />
            <TextField
              name="username"
              defaultValue={formState.fields.username || ""}
              autoFocus
              required
            />
          </div>
          <div>
            <Label
              htmlFor="password"
              title="Password"
              hasError={formState.errors.password && !isPending}
            />
            <TextField
              name="password"
              type="password"
              required
              hasError={formState.errors.password && !isPending}
            />
            {formState.errors.password && !isPending && (
              <p className="mt-3 flex text-sm gap-1 leading-6 text-rose-600">
                <strong>Error:</strong> {formState.errors.password.message}
              </p>
            )}
          </div>

          <div className="mt-2 flex items-center justify-between gap-6">
            <button
              disabled={isPending}
              className="w-full rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80 disabled:text-white/80 disabled:bg-zinc-900/50"
              type="submit"
            >
              Login
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
