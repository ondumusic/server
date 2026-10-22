import { memo } from "react";
import { Trans } from "react-i18next";
import { classNames } from "../../utils/classNames";
import { formatTotalDuration } from "../../utils/formatTotalDuration";
import { PlayShuffleButtons } from "../PlayShuffleButtons";
import type { HeaderItem } from "./types";

interface Props {
  item: HeaderItem;
}

export const PlaylistHeaderRow = memo(({ item }: Props) => {
  return (
    <header className="pt-4 lg:pt-5 @md:pb-6 flex items-end justify-between gap-4">
      <div className="min-w-0">
        <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
          {item.playlist.name}
        </h1>
        <span
          className={classNames([
            "text-sm text-page-fg-muted",
            item.playlist.trackCount === 0 && "hidden",
          ])}
        >
          <Trans
            i18nKey="playlist.trackCount"
            count={item.playlist.trackCount}
            duration={formatTotalDuration(item.totalDuration)}
          >
            {{ count: item.playlist.trackCount }} tracks,{" "}
            {{ duration: formatTotalDuration(item.totalDuration) }}
          </Trans>
        </span>
      </div>

      {item.playlist.trackCount > 0 && (
        <PlayShuffleButtons
          input={{ playlistId: item.playlist.id }}
          className="flex-shrink-0"
        />
      )}
    </header>
  );
});
