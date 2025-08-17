import { Navigate, Outlet, useLocation } from "react-router";
import { RootLayout } from "../layouts/RootLayout";

export function PrivateRootLayout() {
  // TODO: use Auth context/service
  const location = useLocation();
  const token = localStorage.sessionToken;
  if (!token) {
    return <Navigate to="/login" replace state={{ redirectTo: location }} />;
  }

  return (
    <RootLayout>
      <Outlet />
    </RootLayout>
  );
}
