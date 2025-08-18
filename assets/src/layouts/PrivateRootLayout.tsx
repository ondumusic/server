import { Navigate, Outlet, useLocation } from "react-router";
import { useAuth } from "../hooks/useAuth";
import { RootLayout } from "../layouts/RootLayout";

export function PrivateRootLayout() {
  const location = useLocation();
  const { isLoggedIn, logout } = useAuth();

  if (!isLoggedIn) {
    logout();
    return <Navigate to="/login" replace state={{ redirectTo: location }} />;
  }

  return (
    <RootLayout>
      <Outlet />
    </RootLayout>
  );
}
