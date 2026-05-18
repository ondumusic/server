import { classNames } from "../../utils/classNames";

interface Props {
  id?: string;
  name: string;
  defaultValue?: string | number;
  options: { [key: string]: string };
  type?: string;
  hasError?: boolean;
  required?: boolean;
  multiple?: boolean;
  autoFocus?: boolean;
}

export function Select(props: Props) {
  return (
    <select
      id={props.id || props.name}
      key={props.defaultValue}
      name={props.name}
      className={classNames([
        "mt-2 block w-full rounded-md border shadow-sm focus:ring-0 sm:text-sm",
        "border-zinc-400/60 bg-white/80 focus:border-zinc-400",
        "dark:border-zinc-400/50 dark:bg-black/40 dark:focus:border-zinc-200/50",
        !props.hasError && "border-zinc-300 focus:border-zinc-400",
        props.hasError && "border-rose-400 focus:border-rose-400",
      ])}
      multiple={props.multiple}
      required={props.required || false}
      defaultValue={props.defaultValue}
    >
      {Object.entries(props.options).map(([value, title]) => (
        <option key={`${props.name}-${value}`} value={value}>
          {title}
        </option>
      ))}
    </select>
  );
}
