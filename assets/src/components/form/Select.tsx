import { classNames } from "../../utils/classNames";

interface Props {
  id?: string;
  name: string;
  value?: string;
  options: { [key: string]: string };
  type?: string;
  hasError?: boolean;
  required?: boolean;
  multiple?: boolean;
  autoFocus?: boolean;
  onChange?: (value: string) => void;
}

export function Select(props: Props) {
  return (
    <select
      id={props.id || props.name}
      name={props.name}
      value={String(props.value ?? "")}
      onChange={(e) => props.onChange?.(e.target.value)}
      className={classNames([
        "mt-2 block w-full rounded-md border shadow-sm focus:ring-0 sm:text-sm",
        "border-zinc-400/60 bg-white/80 focus:border-zinc-400",
        "dark:border-white/10 dark:bg-white/5 dark:focus:border-white/30",
        !props.hasError && "border-zinc-300 focus:border-zinc-400",
        props.hasError && "border-rose-400 focus:border-rose-400",
      ])}
      multiple={props.multiple}
      required={props.required || false}
    >
      {Object.entries(props.options).map(([value, title]) => (
        <option key={`${props.name}-${value}`} value={value}>
          {title}
        </option>
      ))}
    </select>
  );
}
