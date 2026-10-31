import { useLocation, useNavigate, useRouter } from "@tanstack/react-router";
import { type KeyboardEvent, useEffect, useRef, useState } from "react";
import i18next from "../i18next";
import { classNames } from "../utils/classNames";
import { ClearIcon } from "./icons/ClearIcon";
import { SearchIcon } from "./icons/SearchIcon";

interface SearchParams {
  q?: unknown;
}

const queryFromSearch = ({ q }: SearchParams): string => {
  return q === undefined || q === null ? "" : String(q);
};

const searchFieldId = "search-field";

export const focusSearchField = () => {
  const input = document.getElementById(searchFieldId);
  if (!(input instanceof HTMLInputElement)) return false;

  input.focus();
  input.select();
  return true;
};

export function SearchField() {
  const navigate = useNavigate();
  const router = useRouter();
  const location = useLocation();
  const inputRef = useRef<HTMLInputElement>(null);

  // We only want to replace history when we are on the search page,
  // if we always push it would populate every keystroke which is not ideal.
  const onSearchPage = location.pathname === "/search";

  // Get the query from search
  let searchQuery = "";
  if (onSearchPage) searchQuery = queryFromSearch(location.search);

  // The input has its own state to avoid cursor jumping on history changes
  const [value, setValue] = useState(searchQuery);
  const lastQuery = useRef(searchQuery);

  // Update the text field value if the search `q` param changed
  useEffect(() => {
    if (searchQuery === lastQuery.current) return;
    lastQuery.current = searchQuery;
    setValue(searchQuery);
  }, [searchQuery]);

  // When text field changes we also push or replace history, depending on
  // what page we are currently on.
  const updateQuery = (query: string) => {
    setValue(query);
    lastQuery.current = query;

    navigate({
      to: "/search",
      search: query ? { q: query } : {},
      replace: onSearchPage,
    });
  };

  const handleClear = () => {
    updateQuery("");
    inputRef.current?.focus();
  };

  const handleKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key !== "Escape") return;
    e.preventDefault();
    inputRef.current?.blur();

    if (!onSearchPage) return;
    if (router.history.canGoBack()) {
      router.history.back();
    } else {
      navigate({ to: "/" });
    }
  };

  return (
    <div
      className={classNames([
        "relative bg-sidebar-inactive-bg text-page-fg rounded-md",
        "focus-within:ring-2 focus-within:ring-accent-500/60",
      ])}
    >
      <SearchIcon
        className="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 size-4 text-page-fg-muted"
        title=""
        strokeWidth={2}
      />
      <input
        ref={inputRef}
        id={searchFieldId}
        type="text"
        value={value}
        placeholder={i18next.t("search.placeholder", {
          defaultValue: "Search",
        })}
        autoComplete="off"
        spellCheck={false}
        onChange={(e) => updateQuery(e.target.value)}
        onKeyDown={handleKeyDown}
        className={classNames([
          "block w-full h-8 pl-8 pr-8 border-0 rounded-md text-sm",
          "bg-transparent text-page-fg placeholder:text-page-fg-muted",
          "outline-0 ring-0 focus:ring-0 focus:outline-0",
        ])}
      />
      {value && (
        <button
          type="button"
          onMouseDown={(e) => e.preventDefault()}
          onClick={handleClear}
          className="absolute right-2 top-1/2 -translate-y-1/2 text-page-fg-muted hover:text-page-fg"
        >
          <ClearIcon
            className="size-4"
            title={i18next.t("search.clear", { defaultValue: "Clear search" })}
          />
        </button>
      )}
    </div>
  );
}
