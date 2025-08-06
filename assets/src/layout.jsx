import { Outlet, useNavigation } from "react-router";

const MainMenu = () => <p>Menu</p>;

export function Layout() {
  const navigation = useNavigation();
  const isIdle = navigation.state === "idle";
  console.log(isIdle);

  return (
    <>
      <MainMenu />
      <Outlet />
    </>
  );
}
