import { classNames } from "../../utils/classNames";

interface Props {
  id?: string;
  name: string;
  defaultValue?: string | number;
  type?: string;
  hasError?: boolean;
  required?: boolean;
  autoFocus?: boolean;
}

export function TextField(props: Props) {
  return (
    <input
      id={props.id || props.name}
      name={props.name}
      type={props.type || "text"}
      className={classNames([
        "mt-2 block w-full rounded-lg focus:ring-0 sm:text-sm sm:leading-6",
        "bg-white/80 dark:bg-black/40",
        !props.hasError &&
          "border-zinc-400/60 focus:border-zinc-400 dark:border-zinc-400/50 dark:focus:border-zinc-200/50",
        props.hasError && "border-rose-400 focus:border-rose-400",
      ])}
      defaultValue={props.defaultValue}
      required={props.required || false}
    />
  );
}
