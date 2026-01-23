import { ErrorComponent, Navigate, useLocation } from "@tanstack/react-router";
import { type PropsWithChildren, useEffect } from "react";
import { useAuth } from "../hooks/useAuth";
import { ApiError } from "../services/api";

export function RootErrorBoundary({
  error,
  reset,
}: PropsWithChildren<{ error: Error; reset: () => void }>) {
  const location = useLocation();
  const { isLoggedIn, logout } = useAuth();
  const unauthorizedError =
    error instanceof ApiError && error.response.status === 401;

  useEffect(() => {
    if (unauthorizedError) {
      logout();
      reset();
    }
  }, [unauthorizedError, logout, reset]);

  if (unauthorizedError && !isLoggedIn) {
    reset();
    return (
      <Navigate to="/login" search={{ redirect: location.href }} replace />
    );
  }

  if (import.meta.env.MODE === "dev") {
    return <ErrorComponent error={error} />;
  }

  return <div>Oops! Something went wrong.</div>;
}
