import { type PropsWithChildren, useEffect, useRef, useState } from "react";
import { classNames } from "../utils/classNames";

export interface DropdownOption<T> {
  value: T;
  label: string;
  sublabel?: string;
  badge?: string | number;
}

export function FloatingDropdown<T>({
  children,
  options,
  onChange,
  value: currentValue,
}: PropsWithChildren<{
  value: T;
  options: DropdownOption<T>[];
  onChange: (value: T) => void;
}>) {
  const optionsRef = useRef<HTMLDivElement>(null);
  const [showOptions, setShowOptions] = useState(false);

  useEffect(() => {
    if (!showOptions) return;

    // Close on click or scroll outside
    const handleClickOrScroll = (e: Event) => {
      if (!optionsRef.current) return;

      if (!optionsRef.current.contains(e.target as Node)) {
        setShowOptions(false);
      }
    };

    // Handle keyboard button presses
    const handleKeyDown = (e: KeyboardEvent) => {
      switch (e.key) {
        case "Escape":
          e.stopPropagation();
          setShowOptions(false);
          break;
      }
    };

    document.addEventListener("scroll", handleClickOrScroll, true);
    document.addEventListener("mousedown", handleClickOrScroll);
    document.addEventListener("keydown", handleKeyDown, true);

    return () => {
      document.removeEventListener("scroll", handleClickOrScroll, true);
      document.removeEventListener("mousedown", handleClickOrScroll);
      document.removeEventListener("keydown", handleKeyDown, true);
    };
  }, [showOptions]);

  const selectOption = (value: T) => {
    onChange(value);
    setShowOptions(false);
  };

  return (
    <div className="relative inline-block">
      {showOptions === false ? (
        <button
          type="button"
          onClick={() => {
            setShowOptions(!showOptions);
          }}
          className={classNames([
            "flex gap-2 items-center",
            "absolute top-0 right-0 z-[1000] select-none cursor-pointer",
            "rounded-full shadow-lg hover:shadow-xl border-1 p-1.5 px-3 text-sm whitespace-nowrap",
            "backdrop-blur-2xl backdrop-saturate-150 transition-all font-normal",
            "text-floating-menu-fg border-floating-menu-border bg-floating-menu-bg hover:bg-floating-menu-bg-hover",
          ])}
        >
          {children}
        </button>
      ) : (
        <div
          ref={optionsRef}
          role="listbox"
          className={classNames([
            "floating-dropdown",
            "absolute top-0 right-0 min-w-[180px] z-[1000] select-none",
            "rounded-xl shadow-lg border-1 p-2 whitespace-nowrap",
            "backdrop-blur-2xl backdrop-saturate-150",
            "border-floating-menu-border bg-floating-menu-bg-hover",
          ])}
        >
          {options.map((option) => (
            <div
              key={option.value as string}
              className={classNames([
                "text-left text-sm cursor-pointer px-2 py-2.5 rounded-md group/option",
                "hover:bg-accent-400 hover:text-white",
              ])}
              role="option"
              tabIndex={0}
              aria-selected={option.value === currentValue}
              onClick={() => selectOption(option.value)}
              onKeyDown={() => selectOption(option.value)}
            >
              <span className="flex items-center justify-between gap-4">
                {option.label}
                {option.badge !== undefined && (
                  <DropdownBadge>{option.badge}</DropdownBadge>
                )}
              </span>
              {option.sublabel && option.value === currentValue && (
                <span className="block text-xs text-muted group-hover/option:text-white">
                  {option.sublabel}
                </span>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export function DropdownBadge({ children }: PropsWithChildren) {
  return (
    <span className="rounded-full px-1.5 min-w-5 text-xs leading-5 text-center bg-black/5 dark:bg-white/10 group-hover/option:bg-white/25">
      {children}
    </span>
  );
}
