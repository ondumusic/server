import { memo } from "react";
import { Trans } from "react-i18next";
import { classNames } from "../../utils/classNames";
import { formatTotalDuration } from "../../utils/formatTotalDuration";
import type { HeaderItem } from "./types";

interface Props {
  item: HeaderItem;
}

export const PlaylistHeaderRow = memo(({ item }: Props) => {
  return (
    <header className="mt-18 md:mt-4 lg:mt-5 @md:mb-2 @md:pb-4">
      <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
        {item.playlist.name}
      </h1>
      <span
        className={classNames([
          "text-sm text-panel-fg-muted",
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
    </header>
  );
});
