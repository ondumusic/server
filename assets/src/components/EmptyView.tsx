import type { PropsWithChildren } from "react";

export function EmptyView({
  children,
  message,
}: PropsWithChildren<{
  message: string;
}>) {
  return (
    <div className="h-full content-center text-center text-muted">
      <p>{message}</p>
      {children}
    </div>
  );
}
