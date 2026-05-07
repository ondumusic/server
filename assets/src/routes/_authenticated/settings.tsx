import { createFileRoute, Outlet } from "@tanstack/react-router";
import { Panel } from "../../components/Panel";
import { useAuth } from "../../hooks/useAuth";
import { useTheme } from "../../hooks/useTheme";
import { repo } from "../../library";

export const Route = createFileRoute("/_authenticated/settings")({
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

function SettingsLayout() {
  const { theme, setTheme } = useTheme();
  const { currentUser, logout } = useAuth();

  return (
    <Panel>
      Settings: Coming Soon
      <hr />
      Logged in as: <strong>{currentUser?.username}</strong> - (
      <button type="button" onClick={logout} className="cursor-pointer">
        logout
      </button>
      )
      <br />
      <h3 className="font-bold">debug options</h3>
      <button
        type="button"
        className="bg-red-600 dark:bg-red-400 text-white py-1.5 px-2 text-sm rounded-md shadow-md"
        onClick={() => repo.teardown().then(() => location.reload())}
      >
        delete local indexeddb and refresh
      </button>
      <br />
      <br />
      Theme:
      <ul className="inline-flex pl-4 gap-2">
        <li
          className={
            "border rounded-md shadow-md text-sm " +
            (theme === "auto" && "bg-blue-500 text-white border-transparent")
          }
        >
          <button
            type="button"
            className="py-0.5 px-2 cursor-pointer"
            onClick={() => setTheme("auto")}
          >
            Auto
          </button>
        </li>
        <li
          className={
            "border rounded-md shadow-md text-sm " +
            (theme === "dark" && "bg-blue-500 text-white border-transparent")
          }
        >
          <button
            type="button"
            className="py-0.5 px-2 cursor-pointer"
            onClick={() => setTheme("dark")}
          >
            Dark
          </button>
        </li>
        <li
          className={
            "border rounded-md shadow-md text-sm " +
            (theme === "light" && "bg-blue-500 text-white border-transparent")
          }
        >
          <button
            type="button"
            className="py-0.5 px-2 cursor-pointer"
            onClick={() => setTheme("light")}
          >
            Light
          </button>
        </li>
      </ul>
      <Outlet />
    </Panel>
  );
}
