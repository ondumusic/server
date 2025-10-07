import type { ReactNode } from "react";

interface Props {
  className?: string;
  children: ReactNode;
}

export function FormActions({ className = "gap-4", children }: Props) {
  return (
    <div className={`mt-2 flex items-center justify-between ${className}`}>
      {children}
    </div>
  );
}
