import { type Location, useLocation, useNavigate } from "react-router";
import { useActionState } from "react";

import { api } from "../services/api";

interface RedirectLocationState {
  redirectTo: Location;
}

type LoginFields = {
  username: string;
  password: string;
};


function Label(props) {
  return <label for={props.for}>{props.title}</label>
}

function Input(props) {
  return <input id={props.name} name={props.name} type={props.type || "text"} defaultValue={props.defaultValue} required={props.required || false} />
}

export function LoginView() {
  const navigate = useNavigate();
  const { state } = useLocation();

  const onSubmit = async (prevState, formData) => {
    const newState = {
      fields: {
        username: formData.get("username"),
        password: formData.get("password"),
      },
      errors: {}
    }

    // 'use server';
    const response = await api.post("/auth/login", newState.fields);

    if (!response.error) {
      localStorage.sessionToken = response.sessionToken;

      if (state) {
        const { redirectTo } = state as RedirectLocationState;
        navigate(`${redirectTo.pathname}${redirectTo.search}`);
      } else {
        navigate(`/`);
      }
    }

    return newState
  };

  // const { pending, data, method, action } = useFormStatus();
  const [formState, formAction, isPending] = useActionState(onSubmit, {
    fields: {},
    errors: {}
  });

  // This is where React 19 still has some gaps. So far, there’s no built-in validation system beyond standard HTML validation attributes (required, pattern, etc.).


  return (
    <div className="h-full content-center text-center">
      <h1 className="text-xl mb-4">Login {isPending}</h1>
      <form action={formAction}>
        <ul>
          <li>
            <Label for="username" title="Username" />
            <Input name="username" defaultValue={formState.fields.username || ""} required />
          </li>
          <li>
            <Label for="password" title="Password" />
            <Input name="password" type="password" required />
          </li>
        </ul>

        <button type="submit">Login</button>
      </form>
    </div>
  );
}
