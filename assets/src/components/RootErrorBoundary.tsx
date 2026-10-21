import {
  ErrorComponent,
  type ErrorComponentProps,
  Navigate,
  useLocation,
} from "@tanstack/react-router";
import { useEffect } from "react";
import { Trans } from "react-i18next";
import { ClientError } from "../api";
import { useAuth } from "../hooks/useAuth";
import { WarningIcon } from "./icons/WarningIcon";

export function RootErrorBoundary({ error, reset }: ErrorComponentProps) {
  const location = useLocation();
  const { isLoggedIn, logout } = useAuth();
  const abortedError = error instanceof ClientError && error.aborted;
  const unauthorizedError =
    error instanceof ClientError && error.response?.status === 401;

  useEffect(() => {
    if (unauthorizedError) {
      if (!abortedError) logout();
      reset();
    }
  }, [abortedError, unauthorizedError, logout, reset]);

  if (unauthorizedError && !isLoggedIn) {
    reset();
    return (
      <Navigate to="/login" search={{ redirect: location.href }} replace />
    );
  }

  if (import.meta.env.MODE === "dev") {
    return <ErrorComponent error={error} />;
  }

  return (
    <div className="h-full w-full content-center px-6 text-center text-page-fg">
      <WarningIcon
        className="size-8 mx-auto mb-4 text-page-fg-muted"
        title=""
      />
      <h1 className="font-semibold">
        <Trans i18nKey="errorBoundary.title">Something went wrong</Trans>
      </h1>
      <p className="mt-1 mx-auto max-w-sm text-sm text-page-fg-muted">
        <Trans i18nKey="errorBoundary.description">
          Reload the page to try again.
        </Trans>
      </p>
      <button
        type="button"
        onClick={() => window.location.reload()}
        className="mt-6 rounded-md py-1.5 px-4 text-sm font-medium cursor-pointer bg-accent-500 hover:bg-accent-600 text-white"
      >
        <Trans i18nKey="errorBoundary.reload">Reload</Trans>
      </button>
    </div>
  );
}
