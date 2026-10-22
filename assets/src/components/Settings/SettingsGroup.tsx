import type { PropsWithChildren } from "react";

export function SettingsGroup({
  title,
  children,
}: PropsWithChildren<{ title?: string }>) {
  return (
    <section>
      {title && <h2 className="mb-2 text-sm font-semibold">{title}</h2>}

      <div className="divide-y divide-page-fg-divider border-y border-page-fg-divider *:py-4">
        {children}
      </div>
    </section>
  );
}
