import { Navigate, Outlet } from "react-router";
import { RootLayout } from "../layouts/RootLayout";

export function PrivateRootLayout() {
    // TODO: use Auth context/service
    let token = localStorage["sessionToken"]
    if (!token) return <Navigate to="/login" />

    return <RootLayout>
        <Outlet />
    </RootLayout>
}
