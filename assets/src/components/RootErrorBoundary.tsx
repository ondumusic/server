import { Navigate, useLocation, useRouteError } from "react-router";
import { ApiError } from "../services/api";

export function RootErrorBoundary() {
  const error = useRouteError() as Error;
  const location = useLocation();

  if (error instanceof ApiError && error.response.status === 401) {
    return <Navigate to="/login" replace state={{ redirectTo: location }} />;
  }

  // TODO: Deal with other errors, maybe show a dialog or something?

  return <div>Oops! Something went wrong.</div>;
}
