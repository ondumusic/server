import { classNames } from "../utils/classNames";

interface Props {
  htmlFor: string;
  title: string;
  hasError?: boolean;
}

export function Label(props: Props) {
  return (
    <label
      htmlFor={props.htmlFor}
      className={classNames([
        "block text-sm font-semibold leading-6",
        !props.hasError && "text-zinc-800",
        props.hasError && "text-rose-600",
      ])}
    >
      {props.title}
    </label>
  );
}
