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
        "flex mx-auto overflow-hidden text-panel-fg",
        "border border-panel-border",
        main && "h-full w-full lg:shadow-lg lg:rounded-md",
        !main &&
          "max-w-md p-6 backdrop-blur-2xl backdrop-saturate-150 bg-panel-bg flex-col shadow-lg rounded-md",
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
