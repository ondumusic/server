import type { ReactNode } from "react";

interface Props {
  children: ReactNode;
}

export function FormActions({ children }: Props) {
  return (
    <div className="mt-2 flex items-center justify-between gap-6">
      {children}
    </div>
  );
}
