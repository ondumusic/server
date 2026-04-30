import type { PropsWithChildren } from "react";
import { classNames } from "../../utils/classNames";

type ButtonStyle = "primary" | "secondary" | "danger";

interface Colors {
  button: string;
  link: string;
}

const styleColors = (style?: ButtonStyle): Colors => {
  switch (style) {
    case "secondary":
      return {
        button:
          "bg-zinc-900 hover:bg-zinc-700 text-white active:text-white/80 disabled:text-white/80 disabled:bg-zinc-900/50",
        link: "text-zinc-800 hover:text-zinc-700 active:text-black disabled:text-zinc-400",
      };
    case "danger":
      return {
        button:
          "bg-rose-900 hover:bg-rose-700 text-white active:text-white/80 disabled:text-white/80 disabled:bg-rose-900/50",
        link: "text-rose-800 hover:text-rose-700 active:text-black disabled:text-rose-400",
      };
    default:
      return {
        button:
          "bg-accent-700 hover:bg-accent-800 text-white active:text-white/80 disabled:text-white/80 disabled:bg-accent-900/50",
        link: "text-accent-600 hover:text-zinc-700 active:text-black disabled:text-zinc-400",
      };
  }
};

export function Button({
  children,
  disabled,
  link,
  style,
  type,
  onClick,
}: PropsWithChildren<{
  disabled?: boolean;
  style?: ButtonStyle;
  link?: boolean;
  type: "submit" | "button";
  onClick?: () => void;
}>) {
  const colors: Colors = styleColors(style);

  return (
    <button
      disabled={!!disabled}
      className={classNames([
        "w-full cursor-pointer disabled:cursor-default rounded-lg py-2 px-3 text-sm font-semibold leading-6",
        link && colors.link,
        !link && colors.button,
      ])}
      type={type}
      onClick={onClick}
    >
      {children}
    </button>
  );
}
