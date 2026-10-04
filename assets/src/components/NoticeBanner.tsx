import { useState, useSyncExternalStore } from "react";
import { type Notice, noticeApi } from "../api/notices";
import i18next from "../i18next";
import { notices } from "../services/notices";
import { classNames } from "../utils/classNames";
import { ChevronDownIcon } from "./icons/ChevronDownIcon";
import { WarningIcon } from "./icons/WarningIcon";

function noticeText(notice: Notice): { title: string; description: string } {
  switch (notice.code) {
    case "library_unavailable":
      return {
        title: i18next.t("notices.libraryUnavailable.title", {
          defaultValue: "Music folder unavailable",
        }),
        description: i18next.t("notices.libraryUnavailable.description", {
          defaultValue:
            "No music was found in your music folder, it might be unavailable (e.g. an unmounted network share). Your library is not updated until it is available again.",
        }),
      };
    default:
      return { title: notice.message, description: notice.message };
  }
}

async function dismiss(id: string) {
  notices.set(notices.get().filter((notice) => notice.id !== id));
  const response = await noticeApi.dismiss(id);
  if (response) notices.set(response.notices);
}

export function NoticeBanner() {
  const active = useSyncExternalStore(notices.subscribe, notices.get);
  if (active.length === 0) return null;

  return (
    <div
      className={classNames([
        "fixed z-50 flex flex-col gap-2",
        "bottom-24 left-1/2 -translate-x-1/2 w-max max-w-[calc(100%-32px)] items-center",
        "lg:bottom-auto lg:top-6 lg:left-4 lg:translate-x-0 lg:w-76 lg:items-stretch",
      ])}
    >
      {active.map((notice) => (
        <NoticePill key={notice.id} notice={notice} />
      ))}
    </div>
  );
}

function NoticePill({ notice }: { notice: Notice }) {
  const [expanded, setExpanded] = useState(false);
  const { title, description } = noticeText(notice);

  return (
    <div
      role="status"
      className={classNames([
        "rounded-2xl shadow-md text-sm",
        // It sits on the dark player background in both themes, so a tint of
        // the level color works for both.
        "backdrop-blur-2xl ring-1",
        notice.level === "warning"
          ? "bg-amber-400/15 text-amber-100 ring-amber-300/25"
          : "bg-white/10 text-white ring-white/15",
      ])}
    >
      <button
        type="button"
        className="flex items-center gap-2 px-4 py-2 w-full cursor-pointer"
        aria-expanded={expanded}
        onClick={() => setExpanded(!expanded)}
      >
        {notice.level === "warning" && (
          <WarningIcon className="size-4 shrink-0 text-amber-300" title="" />
        )}
        <span className="font-medium line-clamp-1 text-left">{title}</span>
        <ChevronDownIcon
          className={classNames([
            "size-4 shrink-0 ml-auto transition-transform",
            expanded && "rotate-180",
          ])}
          title=""
        />
      </button>

      {expanded && (
        <div className="px-4 pb-3 space-y-2">
          <p>{description}</p>
          <button
            type="button"
            className="underline hover:no-underline cursor-pointer"
            onClick={() => dismiss(notice.id)}
          >
            {i18next.t("notices.dismiss", { defaultValue: "Dismiss" })}
          </button>
        </div>
      )}
    </div>
  );
}
