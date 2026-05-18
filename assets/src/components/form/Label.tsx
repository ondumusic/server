import { classNames } from "../../utils/classNames";

interface Props {
  htmlFor: string;
  title: string;
  hasError?: boolean;
  horizontal?: boolean;
}

export function Label(props: Props) {
  return (
    <label
      htmlFor={props.htmlFor}
      className={classNames([
        "block text-sm font-semibold leading-6",
        props.horizontal && "col-span-2 pt-3",
        !props.hasError && "text-label",
        props.hasError && "text-error",
      ])}
    >
      {props.title}
    </label>
  );
}
