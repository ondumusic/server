import type { ReactNode } from "react";

interface Props {
  children: ReactNode;
}

export function Panel({ children }: Props) {
  return (
    <div className="mx-auto max-w-md rounded-md p-6 shadow-lg bg-panel-bg text-panel-fg">
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
