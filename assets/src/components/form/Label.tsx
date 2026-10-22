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
        "block text-sm leading-6",
        props.horizontal
          ? "@xl:w-48 flex-shrink-0 @xl:pt-2 font-medium"
          : "font-semibold",
        !props.hasError && "text-label",
        props.hasError && "text-error",
      ])}
    >
      {props.title}
    </label>
  );
}
