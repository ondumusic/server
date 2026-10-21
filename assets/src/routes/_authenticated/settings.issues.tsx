import { createFileRoute, Link } from "@tanstack/react-router";
import {
  type ReactNode,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { Trans, useTranslation } from "react-i18next";
import {
  type AlbumIssues,
  type Issue,
  type IssueCode,
  type IssueEntry,
  issueApi,
  scanApi,
  type TrackIssues,
} from "../../api";
import { AlbumArtwork } from "../../components/AlbumArtwork";
import {
  DropdownBadge,
  FloatingDropdown,
} from "../../components/FloatingDropdown";
import { CheckIcon } from "../../components/icons/CheckIcon";
import { SpinnerIcon } from "../../components/icons/SpinnerIcon";
import { usePhoenixSocket } from "../../hooks/usePhoenixSocket";
import { useToast } from "../../hooks/useToast";
import i18next from "../../i18next";
import { repo } from "../../library";
import type { Album, Track, UUID } from "../../types";
import { classNames } from "../../utils/classNames";

type Filter = IssueCode | "all";

interface IssuesSearch {
  code?: IssueCode;
}

export const Route = createFileRoute("/_authenticated/settings/issues")({
  staticData: { view: "settings" as const },
  // The selected issue filter, unknown codes show all issues.
  validateSearch: (search: Record<string, unknown>): IssuesSearch => {
    const code = search.code as IssueCode;
    return CODES.includes(code) ? { code } : {};
  },
  component: Issues,
});

// Order of the filters, roughly from most to least severe.
const CODES: IssueCode[] = [
  "artist_missing",
  "album_missing",
  "title_missing",
  "track_number_missing",
  "track_number_duplicate",
  "track_number_gap",
  "release_year_missing",
  "artwork_missing",
  "artwork_low_res",
  "artwork_not_square",
];

function codeLabel(code: IssueCode) {
  switch (code) {
    case "artist_missing":
      return i18next.t("issues.code.artistMissing", {
        defaultValue: "Untagged tracks",
      });
    case "album_missing":
      return i18next.t("issues.code.albumMissing", {
        defaultValue: "No album",
      });
    case "title_missing":
      return i18next.t("issues.code.titleMissing", {
        defaultValue: "No title",
      });
    case "track_number_missing":
      return i18next.t("issues.code.trackNumberMissing", {
        defaultValue: "No track number",
      });
    case "track_number_duplicate":
      return i18next.t("issues.code.trackNumberDuplicate", {
        defaultValue: "Duplicate track numbers",
      });
    case "track_number_gap":
      return i18next.t("issues.code.trackNumberGap", {
        defaultValue: "Gaps in track numbers",
      });
    case "release_year_missing":
      return i18next.t("issues.code.releaseYearMissing", {
        defaultValue: "No release year",
      });
    case "artwork_missing":
      return i18next.t("issues.code.artworkMissing", {
        defaultValue: "No artwork",
      });
    case "artwork_low_res":
      return i18next.t("issues.code.artworkLowRes", {
        defaultValue: "Low resolution artwork",
      });
    case "artwork_not_square":
      return i18next.t("issues.code.artworkNotSquare", {
        defaultValue: "Artwork not square",
      });
  }
}

function formatNumbers(numbers: number[] = []) {
  return numbers.join(", ");
}

function describeIssue(issue: Issue): string {
  const { details } = issue;
  const count = details.trackIds?.length ?? 0;
  const disc = details.disc && details.disc > 1 ? details.disc : undefined;

  switch (issue.code) {
    case "artist_missing":
      return i18next.t("issues.issue.artistMissing", {
        defaultValue: "No artist, album or title",
      });
    case "album_missing":
      return i18next.t("issues.issue.albumMissing", {
        defaultValue: "Tracks without an album tag",
      });
    case "title_missing":
      return count
        ? i18next.t("issues.issue.titleMissingTracks", {
            defaultValue: "{{count}} tracks without a title",
            count,
          })
        : i18next.t("issues.issue.titleMissing", {
            defaultValue: "No title",
          });
    case "track_number_missing":
      return i18next.t("issues.issue.trackNumberMissing", {
        defaultValue: "{{count}} tracks without a track number",
        count,
      });
    case "track_number_duplicate":
      return disc
        ? i18next.t("issues.issue.trackNumberDuplicateDisc", {
            defaultValue:
              "Track {{numbers}} used more than once on disc {{disc}}",
            numbers: formatNumbers(details.numbers),
            disc,
          })
        : i18next.t("issues.issue.trackNumberDuplicate", {
            defaultValue: "Track {{numbers}} used more than once",
            numbers: formatNumbers(details.numbers),
          });
    case "track_number_gap":
      return disc
        ? i18next.t("issues.issue.trackNumberGapDisc", {
            defaultValue: "Numbering skips {{numbers}} on disc {{disc}}",
            numbers: formatNumbers(details.numbers),
            disc,
          })
        : i18next.t("issues.issue.trackNumberGap", {
            defaultValue: "Numbering skips {{numbers}}",
            numbers: formatNumbers(details.numbers),
          });
    case "release_year_missing":
      return i18next.t("issues.issue.releaseYearMissing", {
        defaultValue: "No release year",
      });
    case "artwork_missing":
      return i18next.t("issues.issue.artworkMissing", {
        defaultValue: "No artwork found",
      });
    case "artwork_low_res":
      return i18next.t("issues.issue.artworkLowRes", {
        defaultValue: "Low resolution artwork ({{width}}×{{height}})",
        width: details.width,
        height: details.height,
      });
    case "artwork_not_square":
      return i18next.t("issues.issue.artworkNotSquare", {
        defaultValue: "Artwork is not square ({{width}}×{{height}})",
        width: details.width,
        height: details.height,
      });
  }
}

function entryKey(entry: IssueEntry) {
  return entry.__type === "albumIssues"
    ? `album-${entry.album.id}`
    : `track-${entry.track.id}`;
}

function Issues() {
  const { t } = useTranslation();
  const { showToast } = useToast();
  const { waitForScan } = usePhoenixSocket();
  const [entries, setEntries] = useState<IssueEntry[] | null>(null);
  const [error, setError] = useState(false);
  const { code } = Route.useSearch();
  const navigate = Route.useNavigate();
  const filter: Filter = code ?? "all";

  const setFilter = (value: Filter) =>
    navigate({ search: value === "all" ? {} : { code: value }, replace: true });
  const [isScanning, setIsScanning] = useState(false);

  const load = useCallback(async () => {
    try {
      setError(false);
      setEntries(await issueApi.listIssues());
    } catch {
      setError(true);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const counts = useMemo(() => {
    const counts = new Map<IssueCode, number>();
    for (const entry of entries ?? []) {
      for (const code of new Set(entry.issues.map((issue) => issue.code))) {
        counts.set(code, (counts.get(code) ?? 0) + 1);
      }
    }
    return counts;
  }, [entries]);

  const filtered = useMemo(() => {
    if (!entries || filter === "all") return entries ?? [];
    return entries.filter((entry) =>
      entry.issues.some((issue) => issue.code === filter),
    );
  }, [entries, filter]);

  const filterOptions = useMemo(
    () => [
      {
        value: "all" as Filter,
        label: t("settings.issues.allIssues", { defaultValue: "All issues" }),
        badge: entries?.length ?? 0,
      },
      ...CODES.filter((code) => counts.has(code) || code === filter).map(
        (code) => ({
          value: code as Filter,
          label: codeLabel(code),
          badge: counts.get(code) ?? 0,
        }),
      ),
    ],
    [t, entries, counts, filter],
  );

  const summary = useMemo(() => {
    const albums = filtered.filter((e) => e.__type === "albumIssues").length;
    const tracks = filtered.length - albums;

    return [
      albums > 0 &&
        t("settings.issues.albumCount", {
          defaultValue: "{{count}} albums",
          count: albums,
        }),
      tracks > 0 &&
        t("settings.issues.trackCount", {
          defaultValue: "{{count}} tracks",
          count: tracks,
        }),
    ].filter((part): part is string => !!part);
  }, [t, filtered]);

  const currentFilterOption =
    filterOptions.find(({ value }) => value === filter) ?? filterOptions[0];

  const handleScan = async () => {
    setIsScanning(true);
    showToast({
      message: t("toast.startedLibraryScan", {
        defaultValue: "Started scanning the library for new tracks",
      }),
    });

    try {
      await scanApi.startScanner();
      waitForScan(async () => {
        await load();
        setIsScanning(false);
        showToast({
          message: t("toast.completedLibraryScan", {
            defaultValue: "Library scan completed",
          }),
        });
      });
    } catch {
      setIsScanning(false);
    }
  };

  return (
    <div className="px-4 lg:px-8 pb-16">
      <header className="mt-18 md:mt-4 lg:mt-5 @md:pb-4 mb-4 flex items-start justify-between gap-4">
        <div className="min-w-0">
          <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
            <Trans i18nKey="settings.issues.title">Issues</Trans>
          </h1>
          <span className="text-sm text-panel-fg-muted">
            {summary.map((part) => (
              <span key={part}>{part} · </span>
            ))}
            <button
              type="button"
              onClick={handleScan}
              disabled={isScanning}
              className="cursor-pointer disabled:cursor-default text-accent-500 hover:underline disabled:no-underline"
            >
              {isScanning ? (
                <Trans i18nKey="settings.issues.scanning">Scanning…</Trans>
              ) : (
                <Trans i18nKey="settings.issues.rescan">Rescan library</Trans>
              )}
            </button>
          </span>
        </div>

        {/* The dropdown is absolutely positioned from the top right. */}
        {entries && entries.length > 0 && (
          <div className="flex h-8">
            <FloatingDropdown<Filter>
              value={filter}
              options={filterOptions}
              onChange={setFilter}
            >
              {currentFilterOption?.label}
              <DropdownBadge>{currentFilterOption?.badge}</DropdownBadge>
            </FloatingDropdown>
          </div>
        )}
      </header>

      {error && (
        <p className="text-sm text-red-600 dark:text-red-400">
          <Trans i18nKey="settings.issues.error">
            Could not load the issues, try again later.
          </Trans>
        </p>
      )}

      {!entries && !error && (
        <div className="flex justify-center py-16">
          <SpinnerIcon
            className="animate-spin size-6"
            title={t("settings.issues.loading", { defaultValue: "Loading…" })}
          />
        </div>
      )}

      {entries && entries.length === 0 && (
        <div className="flex flex-col items-center gap-2 py-16 text-panel-fg-muted">
          <CheckIcon
            className="size-8 text-accent-500"
            title={t("settings.issues.none", { defaultValue: "No issues" })}
          />
          <span>
            <Trans i18nKey="settings.issues.empty">
              No problems found, your library looks great.
            </Trans>
          </span>
        </div>
      )}

      {/* E.g. after fixing the last album with this issue and rescanning. */}
      {entries &&
        entries.length > 0 &&
        filter !== "all" &&
        filtered.length === 0 && (
          <div className="flex flex-col items-center gap-2 py-16 text-panel-fg-muted">
            <CheckIcon
              className="size-8 text-accent-500"
              title={t("settings.issues.none", { defaultValue: "No issues" })}
            />
            <span>
              {t("settings.issues.emptyFilter", {
                defaultValue: "No more issues for “{{filter}}”.",
                filter: codeLabel(filter),
              })}
            </span>
            <button
              type="button"
              onClick={() => setFilter("all")}
              className="cursor-pointer text-sm text-accent-500 hover:underline"
            >
              <Trans i18nKey="settings.issues.showAll">Show all issues</Trans>
            </button>
          </div>
        )}

      {filtered.length > 0 && (
        <ul className="divide-y divide-panel-fg-divider">
          {filtered.map((entry) => (
            <li key={entryKey(entry)}>
              {entry.__type === "albumIssues" ? (
                <AlbumRow entry={entry} filter={filter} />
              ) : (
                <TrackRow entry={entry} filter={filter} />
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function Row({
  album,
  title,
  subtitle,
  action,
  children,
}: {
  album?: Album | null;
  title: ReactNode;
  subtitle?: ReactNode;
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="flex gap-3 items-start py-2.5 px-2 hover:bg-black/5 dark:hover:bg-white/5">
      <AlbumArtwork
        album={album}
        size="thumbnail"
        className="size-11 flex-shrink-0 rounded-sm shadow-sm bg-linear-to-br from-stone-50 to-stone-200"
      />
      <div className="min-w-0 flex-1">
        <div className="flex items-baseline gap-2 min-w-0 mb-1">
          <span className="font-medium truncate">{title}</span>
          {/* Keeps its width up to half the line, the title is cut off first. */}
          {subtitle && (
            <span className="text-sm text-panel-fg-muted truncate flex-shrink-0 max-w-1/2">
              {subtitle}
            </span>
          )}
          {action && <span className="ml-auto flex-shrink-0">{action}</span>}
        </div>
        {children}
      </div>
    </div>
  );
}

function IssueList({
  issues,
  filter,
  trackNames = new Map(),
}: {
  issues: Issue[];
  filter: Filter;
  trackNames?: Map<UUID, string>;
}) {
  const isActive = (issue: Issue) => filter === "all" || filter === issue.code;

  // Issues matching the filter first, the sort is stable so the order from the
  // api is kept otherwise.
  const sortedIssues = issues.toSorted(
    (a, b) => Number(isActive(b)) - Number(isActive(a)),
  );

  return (
    <ul className="flex flex-wrap gap-1.5">
      {sortedIssues.map((issue) => {
        // The affected tracks are shown on hover to keep the rows compact.
        const names = (issue.details.trackIds ?? [])
          .map((id) => trackNames.get(id))
          .filter((name) => !!name);

        return (
          <li
            key={`${issue.code}-${issue.details.disc ?? ""}`}
            title={names.length > 0 ? names.join("\n") : undefined}
            className={classNames([
              "rounded-full px-2 text-xs leading-5 whitespace-nowrap",
              isActive(issue)
                ? "bg-accent-500/15 text-accent-700 dark:text-accent-300"
                : "bg-black/5 dark:bg-white/10 opacity-60",
            ])}
          >
            {describeIssue(issue)}
          </li>
        );
      })}
    </ul>
  );
}

function AlbumRow({ entry, filter }: { entry: AlbumIssues; filter: Filter }) {
  const { album, artist, issues } = entry;
  const trackNames = useTrackNames(issues);

  return (
    <Row
      album={album}
      title={
        <Link
          to="/albums/$albumId"
          params={{ albumId: album.id }}
          className="hover:underline"
        >
          {album.name}
        </Link>
      }
      subtitle={artist.name}
    >
      <IssueList issues={issues} filter={filter} trackNames={trackNames} />
    </Row>
  );
}

function TrackRow({ entry, filter }: { entry: TrackIssues; filter: Filter }) {
  const { t } = useTranslation();
  const { showToast } = useToast();
  const { track, issues } = entry;

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(track.path);
      showToast({
        message: t("toast.copiedPath", { defaultValue: "Copied file path" }),
      });
    } catch {
      // Clipboard access can be denied, the path is still shown on hover.
    }
  };

  return (
    <Row
      title={track.name}
      action={
        <button
          type="button"
          onClick={handleCopy}
          title={track.path}
          className="cursor-pointer text-xs text-accent-500 hover:underline"
        >
          <Trans i18nKey="settings.issues.copyPath">Copy path</Trans>
        </button>
      }
    >
      <IssueList issues={issues} filter={filter} />
    </Row>
  );
}

// Looks up the names of tracks referenced by issues in the local library.
function useTrackNames(issues: Issue[]) {
  const [names, setNames] = useState<Map<UUID, string>>(new Map());
  const trackIds = useMemo(
    () => issues.flatMap((issue) => issue.details.trackIds ?? []),
    [issues],
  );

  useEffect(() => {
    if (trackIds.length === 0) return;
    let cancelled = false;

    repo.getMany<Track>("tracks", trackIds).then((tracks) => {
      if (cancelled) return;
      setNames(new Map(tracks.map((track) => [track.id, track.name])));
    });

    return () => {
      cancelled = true;
    };
  }, [trackIds]);

  return names;
}
