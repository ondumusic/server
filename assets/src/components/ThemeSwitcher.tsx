import type { PropsWithChildren } from "react";
import { Trans } from "react-i18next";
import { ThemeAutoIcon } from "../components/icons/ThemeAutoIcon";
import { ThemeDarkIcon } from "../components/icons/ThemeDarkIcon";
import { ThemeLightIcon } from "../components/icons/ThemeLightIcon";

const Option = ({
  children,
  value,
  isSelected,
  onChange,
}: PropsWithChildren<{
  value: string;
  isSelected: boolean;
  onChange: (value: string) => void;
}>) => (
  <li
    className={
      "border-y first:border-l border-r first:rounded-l-md last:rounded-r-md text-sm border-muted dark:border-white/60 " +
      (isSelected && "bg-accent-500 text-white")
    }
  >
    <button
      type="button"
      className="flex items-center gap-2 py-1 px-3 cursor-pointer"
      onClick={() => onChange(value)}
    >
      {children}
    </button>
  </li>
);

export const ThemeSwitcher = ({
  value,
  onChange,
}: PropsWithChildren<{
  value: string;
  onChange: (value: string) => void;
}>) => (
  <ul className="inline-flex">
    <Option value="auto" onChange={onChange} isSelected={value === "auto"}>
      <ThemeAutoIcon className="size-4" title="" />
      <Trans i18nKey="themeSwitcher.auto">Auto</Trans>
    </Option>

    <Option value="light" onChange={onChange} isSelected={value === "light"}>
      <ThemeLightIcon className="size-4" title="" />
      <Trans i18nKey="themeSwitcher.light">Light</Trans>
    </Option>
    <Option value="dark" onChange={onChange} isSelected={value === "dark"}>
      <ThemeDarkIcon className="size-4" title="" />
      <Trans i18nKey="themeSwitcher.dark">Dark</Trans>
    </Option>
  </ul>
);
