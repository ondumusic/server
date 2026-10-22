import type { PropsWithChildren, ReactNode } from "react";

export function SettingsActions({
  secondaryAction,
  children,
}: PropsWithChildren<{ secondaryAction?: ReactNode }>) {
  return (
    <div className="flex items-center gap-4 @xl:pl-56">
      <div className="w-48">{children}</div>
      {secondaryAction}
    </div>
  );
}
