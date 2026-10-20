import type { PropsWithChildren } from "react";

export function AuthLayout({
  title,
  subtitle,
  children,
}: PropsWithChildren<{
  title: string;
  subtitle?: string;
}>) {
  return (
    <div className="h-full overflow-auto bg-page-bg text-page-fg">
      <main className="min-h-full flex items-center px-6 py-12 sm:px-12 lg:px-[12vw]">
        <div className="w-full max-w-sm">
          <h1 className="text-4xl font-bold tracking-tight">{title}</h1>
          {subtitle && <p className="mt-3 text-page-fg-muted">{subtitle}</p>}

          <div className="mt-10">{children}</div>
        </div>
      </main>
    </div>
  );
}
