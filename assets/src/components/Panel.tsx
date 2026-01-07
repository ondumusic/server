import type { ReactNode } from "react";
import { classNames } from "../utils/classNames";

interface Props {
  main?: boolean;
  children: ReactNode;
}

export function Panel({ children, main }: Props) {
  return (
    <div
      className={classNames([
        "flex mx-auto rounded-md shadow-lg overflow-hidden bg-panel-bg text-panel-fg",
        main && "h-full w-full border-[2px] border-accent-200",
        !main && "max-w-md p-6 flex-col",
      ])}
    >
      {children}
    </div>
  );
}

interface HeaderProps {
  children?: ReactNode;
  title: string;
}

Panel.Header = ({ title }: HeaderProps) => (
  <header className="text-center">
    <div>
      <h1 className="text-2xl font-semibold leading-8 text-panel-fg">
        {title}
      </h1>
    </div>
  </header>
);
