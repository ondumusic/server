import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Trans } from "react-i18next";
import { ColorPicker } from "../../components/ColorPicker";
import { useDialog } from "../../hooks/useDialog";
import { useTheme } from "../../hooks/useTheme";
import { repo } from "../../library";
import {
  getAccentColor,
  updateAccentColor,
} from "../../utils/updateAccentColor";

export const Route = createFileRoute("/_authenticated/settings/")({
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

function SettingsLayout() {
  const [color, setColor] = useState(getAccentColor());
  const { theme, setTheme } = useTheme();
  const { promptConfirm } = useDialog();

  const handleReset = async () => {
    const confirmed = await promptConfirm({
      danger: true,
      message: "Are you sure you want to reset your local database?",
      confirmMessage: "Reset",
      cancelMessage: "Cancel",
    });
    if (!confirmed) return;
    await repo.teardown();
    location.reload();
  };

  return (
    <div className="h-full mx-4 lg:mx-8">
      <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 mb-8 @md:border-b border-panel-fg-divider">
        <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
          <Trans i18nKey="settings.general.title">General</Trans>
        </h1>
        <span className="text-sm text-panel-fg-muted">
          <Trans i18nKey="settings.general.subtitle">
            Change user preferences
          </Trans>
        </span>
      </header>

      <div className="space-y-12">
        <div>
          <h2 className="font-semibold text-lg">Appearance</h2>
          <p className="text-muted text-sm mb-6">
            Some like it dark, some like it light, some like it auto vroom
            vroom.
          </p>

          <div className="space-y-6">
            <div className="grid grid-cols-8 gap-6">
              <div className="col-span-2 text-sm">
                <h3 className="font-medium">Interface Theme</h3>
              </div>
              <div className="col-span-5">
                <ul className="inline-flex gap-2">
                  <li
                    className={
                      "border rounded-md shadow-md text-sm " +
                      (theme === "auto" &&
                        "bg-accent-500 text-white border-transparent")
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
                      (theme === "dark" &&
                        "bg-accent-500 text-white border-transparent")
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
                      (theme === "light" &&
                        "bg-accent-500 text-white border-transparent")
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
              </div>
            </div>

            <div className="grid grid-cols-8 gap-6">
              <div className="col-span-2 text-sm">
                <h3 className="font-medium">Accent Color</h3>
                {/*<p className="text-muted">
                  Customise the primary colour used throughout the application.
                </p>*/}
              </div>
              <div className="col-span-5">
                <ColorPicker
                  value={color}
                  onChange={(newColor) => {
                    updateAccentColor(newColor);
                    setColor(newColor);
                  }}
                />
              </div>
            </div>
          </div>
        </div>

        <div>
          <h2 className="font-semibold text-lg">Debug Options</h2>
          <p className="text-muted text-sm mb-6">
            For those few times you need to dig deeper.
          </p>

          <button
            type="button"
            className="bg-red-600 dark:bg-red-400 text-white py-1.5 px-2 text-sm rounded-md shadow-md"
            onClick={handleReset}
          >
            delete local indexeddb and refresh
          </button>
        </div>
      </div>
    </div>
  );
}
