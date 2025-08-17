import type { ReactNode } from "react";

interface Props {
  children: ReactNode;
  disabled?: boolean;
  type: "submit" | "button";
}

export function Button({ children, disabled, type }: Props) {
  return (
    <button
      disabled={!!disabled}
      className="w-full cursor-pointer rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3 text-sm font-semibold leading-6 text-white active:text-white/80 disabled:text-white/80 disabled:bg-zinc-900/50"
      type={type}
    >
      {children}
    </button>
  );
}
