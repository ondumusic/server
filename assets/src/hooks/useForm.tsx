import { useActionState } from "react";

export interface Form<T> {
  id: string;
  state: FormState<T>;
  isPending: boolean;
  action(payload: FormData): void;
}

export interface FormErrors {
  [key: string]: {
    message: string;
  };
}

export interface FormState<T> {
  fields: T;
  errors: FormErrors;
}

type SubmitHandler<T> = (
  prevState: FormState<T>,
  formData: FormData,
) => Promise<FormState<T>>;

export function useForm<T>(id: string, onSubmit: SubmitHandler<T>): Form<T> {
  const [formState, formAction, isPending] = useActionState(onSubmit, {
    fields: {} as T,
    errors: {},
  });

  return {
    id,
    state: formState,
    isPending,
    action: formAction,
  };
}
