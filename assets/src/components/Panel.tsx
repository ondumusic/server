import type { PropsWithChildren } from "react";
import { classNames } from "../utils/classNames";

export function Panel({
  children,
  main,
}: PropsWithChildren<{
  main?: boolean;
}>) {
  return (
    <div
      className={classNames([
        "flex mx-auto rounded-md shadow-lg overflow-hidden bg-panel-bg text-panel-fg",
        main && "h-full w-full border-[1px] border-accent-200",
        !main && "max-w-md p-6 flex-col",
      ])}
    >
      {children}
    </div>
  );
}

Panel.Header = ({
  title,
}: PropsWithChildren<{
  title: string;
}>) => (
  <header className="text-center">
    <div>
      <h1 className="text-2xl font-semibold leading-8 text-panel-fg">
        {title}
      </h1>
    </div>
  </header>
);
