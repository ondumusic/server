import { useActionState } from "react";

export interface FormState<T> {
  fields: T;
  errors: {
    [key: string]: {
      message: string;
    };
  };
}

type SubmitHandler<T> = (
  prevState: FormState<T>,
  formData: FormData,
) => Promise<FormState<T>>;

export function useForm<T>(onSubmit: SubmitHandler<T>) {
  return useActionState(onSubmit, {
    fields: {} as T,
    errors: {},
  });
}
