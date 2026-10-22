import type { PropsWithChildren, ReactNode } from "react";

export function SettingsRow({
  label,
  help,
  children,
}: PropsWithChildren<{ label: string; help?: ReactNode }>) {
  return (
    <div className="flex flex-col @xl:flex-row gap-x-8 gap-y-2">
      <div className="@xl:w-48 flex-shrink-0 text-sm font-medium @xl:pt-1.5">
        {label}
      </div>
      <div className="flex-1 min-w-0">
        {children}
        {help && <div className="mt-2 text-sm text-page-fg-muted">{help}</div>}
      </div>
    </div>
  );
}
