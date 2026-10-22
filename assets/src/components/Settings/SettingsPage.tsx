import type { PropsWithChildren, ReactNode } from "react";

export function SettingsPage({
  title,
  subtitle,
  children,
}: PropsWithChildren<{
  title: string;
  subtitle?: ReactNode;
}>) {
  return (
    <div className="mx-4 lg:mx-8 pb-16 max-w-3xl">
      <header className="mt-18 md:mt-4 lg:mt-5 mb-8">
        <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
          {title}
        </h1>
        {subtitle && (
          <div className="text-sm text-page-fg-muted">{subtitle}</div>
        )}
      </header>

      <div className="space-y-10">{children}</div>
    </div>
  );
}
