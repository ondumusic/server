import type { PropsWithChildren } from "react";

export function EmptyView({
  children,
  message,
}: PropsWithChildren<{
  message: string;
}>) {
  return (
    <div className="h-full content-center text-center text-muted/80">
      <p className="text-sm">{message}</p>
      {children}
    </div>
  );
}
