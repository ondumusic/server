import type { PropsWithChildren } from "react";

export function FormActions({
  className = "gap-4",
  children,
}: PropsWithChildren<{
  className?: string;
}>) {
  return (
    <div className={`mt-2 flex items-center justify-between ${className}`}>
      {children}
    </div>
  );
}
