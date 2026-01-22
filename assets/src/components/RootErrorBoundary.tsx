import { ErrorComponent, Navigate, useLocation } from "@tanstack/react-router";
import type { PropsWithChildren } from "react";
import { useAuth } from "../hooks/useAuth";
import { ApiError } from "../services/api";

export function RootErrorBoundary({
  error,
}: PropsWithChildren<{ error: Error }>) {
  const location = useLocation();
  const { logout } = useAuth();

  if (error instanceof ApiError && error.response.status === 401) {
    logout();
    return (
      <Navigate to="/login" search={{ redirect: location.href }} replace />
    );
  }

  if (import.meta.env.MODE === "dev") {
    return <ErrorComponent error={error} />;
  }

  return <div>Oops! Something went wrong.</div>;
}
