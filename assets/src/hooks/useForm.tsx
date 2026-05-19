import { useActionState, useEffect, useState } from "react";

export interface Form<T> {
  id: string;
  key: string;
  state: FormState;
  fields: T;
  horizontal?: boolean;
  isDirty: boolean;
  isPending: boolean;
  updateField<K extends keyof T>(field: K, value: T[K]): void;
  action(payload: FormData): void;
}

export interface FormErrors {
  [key: string]: {
    message: string;
  };
}

export interface FormState {
  ok: boolean | null;
  errors: FormErrors;
}

export interface FormOptions {
  horizontal?: boolean;
}

type SubmitHandler = (
  prevState: FormState,
  formData: FormData,
) => Promise<FormState>;

export function useForm<T>(
  id: string,
  onSubmit: SubmitHandler,
  values: T,
  opts: FormOptions = {},
): Form<T> {
  const [resetKey, setResetKey] = useState(0);
  const [fields, setFields] = useState<T>(values as T);
  const [isDirty, setIsDirty] = useState(false);
  const [state, action, isPending] = useActionState(onSubmit, {
    ok: null,
    errors: {},
  });

  // The useEffect dependency does not do a deep compare so we'll stringify it
  // so we can see when it changed more easily.
  const valueString = JSON.stringify(values);

  // biome-ignore lint/correctness/useExhaustiveDependencies(valueString): suppress dependency valueString
  // biome-ignore lint/correctness/useExhaustiveDependencies(values): suppress dependency values
  useEffect(() => {
    setFields(values as T);
    setIsDirty(false);
    setResetKey((n) => n + 1);
  }, [valueString]);

  useEffect(() => {
    if (!state.ok) return;
    setIsDirty(false);
    setResetKey((n) => n + 1);
  }, [state.ok]);

  const updateField = <K extends keyof T>(field: K, value: T[K]) => {
    setFields((prev) => ({ ...prev, [field]: value }));
    setIsDirty(true);
  };

  return {
    id,
    key: `${id}-${resetKey}`,
    state,
    action,
    fields,
    isDirty,
    isPending,
    updateField,
    ...opts,
  };
}
