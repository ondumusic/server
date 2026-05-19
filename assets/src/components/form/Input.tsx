import type { PropsWithChildren, ReactNode } from "react";
import type { Form } from "../../hooks/useForm";
import { Label } from "./Label";
import { Select } from "./Select";
import { TextField } from "./TextField";
import { TokenField } from "./TokenField";

interface CommonProps<T> {
  form: Form<T>;
  field: string;
  id?: string;
  label?: string;
  help?: ReactNode;
  autoFocus?: boolean;
  required?: boolean;
}

type TextInputProps = {
  type: "text" | "password";
  value?: string;
};

type SelectInputProps = {
  type: "select";
  options: { [key: string]: string };
};

type TokenInputProps = {
  type: "token";
  value?: string[];
};

type InputFieldProps = SelectInputProps | TextInputProps | TokenInputProps;

type Props<T> = CommonProps<T> & InputFieldProps & PropsWithChildren;

export function Input<T>(props: Props<T>) {
  const { form, field, type = "text" } = props;
  const { isPending, fields, state, updateField } = form as Form<T>;

  const id = props.id || `${form.id}__${field}`;
  const hasError = !isPending && !!state.errors[field];

  // Determine what to render based on props.type, default to TextField
  let inputType = "text";
  if (["select", "token"].indexOf(props.type) !== -1) inputType = props.type;

  return (
    <div
      className={
        form.horizontal ? "grid grid-cols-8 gap-6 group/horizontal-form" : ""
      }
    >
      <Label
        htmlFor={id}
        hasError={hasError}
        title={props.label || field}
        horizontal={form.horizontal === true}
      />

      <div className={form.horizontal ? "col-span-5" : ""}>
        {inputType === "select" && (
          <Select
            id={id}
            name={field}
            hasError={hasError}
            value={fields[field as keyof T] as string}
            autoFocus={!!props.autoFocus}
            required={!!props.required}
            options={(props as SelectInputProps).options}
            onChange={(value) =>
              updateField(field as keyof T, value as T[keyof T])
            }
          />
        )}

        {inputType === "text" && (
          <TextField
            id={id}
            name={field}
            type={type}
            hasError={hasError}
            value={fields[field as keyof T] as string}
            autoFocus={!!props.autoFocus}
            required={!!props.required}
            onChange={(value) =>
              updateField(field as keyof T, value as T[keyof T])
            }
          />
        )}

        {inputType === "token" && (
          <TokenField
            id={id}
            name={field}
            hasError={hasError}
            autoFocus={!!props.autoFocus}
            required={!!props.required}
            tokens={fields[field as keyof T] as string[]}
            onChange={(value) =>
              updateField(field as keyof T, value as T[keyof T])
            }
          />
        )}

        {hasError && (
          <p className="mt-3 flex text-sm gap-1 leading-6 text-error">
            {state.errors[field].message}
          </p>
        )}

        {props.help && (
          <div className="mt-3 text-sm leading-6 gap-1 text-muted">
            {props.help}
          </div>
        )}
      </div>
    </div>
  );
}
