import type { ReactNode } from "react";
import type { Form } from "../../hooks/useForm";
import { Label } from "./Label";
import { TextField } from "./TextField";

interface CommonProps<T> {
  children?: ReactNode;
  form: Form<T>;
  field: string;
  id?: string;
  label?: string;
}

// Union type for different input types
type InputFieldProps = {
  type?: string;
  autoFocus?: boolean;
  required?: boolean;
  defaultValue?: string | number;
};
// | {
//     type: "select";
//     options: string[]
//   };

type Props<T> = CommonProps<T> & InputFieldProps;

export function Input<T>(props: Props<T>) {
  const { form, field, type = "text" } = props;
  const { isPending, state } = form as Form<T>;
  const fields = state.fields as T;

  const id = props.id || `${form.id}__${field}`;
  const hasError = !isPending && !!state.errors[field];

  const defaultValue =
    typeof props.defaultValue !== "undefined"
      ? props.defaultValue
      : (fields[field as keyof T] as string);

  return (
    <div>
      <Label htmlFor={id} hasError={hasError} title={props.label || field} />

      {/* TODO: Add support for other fields once needed */}
      <TextField
        id={id}
        name={field}
        type={type}
        hasError={hasError}
        defaultValue={defaultValue}
        autoFocus={!!props.autoFocus}
        required={!!props.required}
      />

      {hasError && (
        <p className="mt-3 flex text-sm gap-1 leading-6 text-rose-600">
          {state.errors[field].message}
        </p>
      )}
    </div>
  );
}
