import { createFileRoute, Outlet } from "@tanstack/react-router";
import { useState } from "react";
import { Panel } from "../../components/Panel";
import { useAuth } from "../../hooks/useAuth";
import { useTheme } from "../../hooks/useTheme";
import { repo } from "../../library";
import {
  getAccentColor,
  isAccessible,
  updateAccentColor,
} from "../../utils/updateAccentColor";

function ColorPicker({
  value,
  onChange,
}: {
  value: string;
  onChange: (color: string) => void;
}) {
  return (
    <label
      className="inline-block relative w-8 h-8 rounded-full border-2 border-white shadow-md cursor-pointer overflow-hidden"
      style={{ backgroundColor: value }}
    >
      <input
        type="color"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
      />
    </label>
  );
}

export const Route = createFileRoute("/_authenticated/settings")({
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

function SettingsLayout() {
  const [color, setColor] = useState(getAccentColor());
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
            (theme === "auto" && "bg-accent-500 text-white border-transparent")
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
            (theme === "dark" && "bg-accent-500 text-white border-transparent")
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
            (theme === "light" && "bg-accent-500 text-white border-transparent")
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
      <br />
      <br />
      <div className="flex gap-2 items-center">
        <span>Accent Color:</span>
        <ColorPicker
          value={color}
          onChange={(newColor) => {
            updateAccentColor(newColor);
            setColor(newColor);
          }}
        />
      </div>
      {!isAccessible(color) && (
        <div className="bg-amber-600 text-white">
          This color could cause poor readability
        </div>
      )}
      <Outlet />
    </Panel>
  );
}
