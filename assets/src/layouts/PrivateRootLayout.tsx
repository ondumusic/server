import { Navigate, Outlet, useLocation } from "react-router";
import { RootLayout } from "../layouts/RootLayout";

export function PrivateRootLayout() {
  // TODO: use Auth context/service
  const token = localStorage.sessionToken;
  if (!token) {
    const location = useLocation();
    return <Navigate to="/login" replace state={{ redirectTo: location }} />;
  }

  return (
    <RootLayout>
      <Outlet />
    </RootLayout>
  );
}
