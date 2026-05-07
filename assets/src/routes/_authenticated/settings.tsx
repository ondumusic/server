import { createFileRoute, Outlet } from "@tanstack/react-router";
import { Panel } from "../../components/Panel";
import { useTheme } from "../../hooks/useTheme";
import { repo } from "../../library";

export const Route = createFileRoute("/_authenticated/settings")({
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

function SettingsLayout() {
  const { theme, setTheme } = useTheme();

  return (
    <Panel>
      Settings: Coming Soon
      <hr />
      <h3 className="font-bold">debug options</h3>
      <button
        type="button"
        className="bg-rose-500 text-white py-1.5 px-2 text-sm rounded-md shadow-md"
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
