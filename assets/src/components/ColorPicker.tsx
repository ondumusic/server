import { Trans } from "react-i18next";
import { CheckIcon } from "../components/icons/CheckIcon";
import { PlusIcon } from "../components/icons/PlusIcon";
import { WarningIcon } from "../components/icons/WarningIcon";
import i18next from "../i18next";
import { isAccessible } from "../utils/updateAccentColor";

export function ColorPicker({
  value,
  onChange,
}: {
  value: string;
  onChange: (color: string) => void;
}) {
  const presets = [
    "#3b82f6", // blue
    "#ea580c", // orange
    "#16a34a", // green
    "#dc2626", // red
    "#4f46e5", // indigo
  ];

  const isPreset = presets.indexOf(value) !== -1;

  return (
    <div>
      <div className="flex flex-wrap gap-2 items-center">
        {presets.map((preset) => (
          <button
            key={preset}
            type="button"
            className="inline-flex justify-center items-center relative w-8 h-8 rounded-full cursor-pointer overflow-hidden"
            onClick={() => onChange(preset)}
            style={{ backgroundColor: preset }}
          >
            {preset === value && <CheckIcon className="size-5" title="" />}
          </button>
        ))}
        <label className="inline-block relative w-8 h-8 rounded-full cursor-pointer overflow-hidden border-1 border-dashed border-black">
          {!isPreset ? (
            <div
              className="absolute scale-80 top-0 left-0 inline-flex justify-center items-center relative w-8 h-8 rounded-full cursor-pointer overflow-hidden"
              style={{ backgroundColor: value }}
            >
              <CheckIcon className="size-5" title="" />
            </div>
          ) : (
            <PlusIcon
              className="absolute scale-80 w-full h-full"
              title={i18next.t("colorPicker.customColor", {
                defaultValue: "Custom colour",
              })}
            />
          )}
          <input
            type="color"
            value={value}
            onChange={(e) => onChange(e.target.value)}
            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
          />
        </label>
      </div>
      {!isAccessible(value) && (
        <div className="flex items-center gap-1 mt-4 text-amber-700 text-sm">
          <WarningIcon className="size-4" title="" />
          <span>
            <Trans i18nKey="colorPicker.readabilityWarning">
              This colour could cause poor readability
            </Trans>
          </span>
        </div>
      )}
    </div>
  );
}
