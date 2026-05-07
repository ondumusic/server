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
          "bg-zinc-900 hover:bg-zinc-700 text-white active:text-white/80 disabled:text-white/80 disabled:bg-zinc-900/50 dark:bg-zinc-200 dark:hover:bg-zinc-300 dark:text-zinc-900 dark:active:text-zinc-900/70 dark:disabled:text-zinc-900/70 dark:disabled:bg-zinc-200/40",
        link: "text-zinc-800 hover:text-zinc-600 active:text-black disabled:text-zinc-400 dark:text-zinc-200 dark:hover:text-zinc-50 dark:active:text-white dark:disabled:text-zinc-600",
      };
    case "danger":
      return {
        button:
          "bg-red-600 hover:bg-red-700 text-white active:text-white/80 disabled:text-white/80 disabled:bg-red-900/50 dark:bg-red-400 dark:hover:bg-red-500 dark:disabled:bg-red-700/40",
        link: "text-rose-800 hover:text-rose-700 active:text-black disabled:text-rose-400 dark:text-rose-300 dark:hover:text-rose-200 dark:active:text-white dark:disabled:text-rose-700",
      };
    default:
      return {
        button:
          "bg-accent-600 hover:bg-accent-700 text-white active:text-white/80 disabled:text-white/80 disabled:bg-accent-900/50",
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
  onClick: handleClick,
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
        !link && ["shadow-md", colors.button],
      ])}
      type={type}
      onClick={handleClick}
    >
      {children}
    </button>
  );
}
