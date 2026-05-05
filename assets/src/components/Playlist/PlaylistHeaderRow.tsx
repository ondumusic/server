import { memo } from "react";
import { Trans } from "react-i18next";
import { formatTotalDuration } from "../../utils/formatTotalDuration";
import type { HeaderItem } from "./types";

interface Props {
  item: HeaderItem;
}

export const PlaylistHeaderRow = memo(({ item }: Props) => {
  return (
    <header className="mt-18 md:mt-4 lg:mt-8 @md:mb-4 @md:pb-4 @md:border-b border-panel-fg-divider">
      <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
        {item.playlist.name}
      </h1>
      <span className="text-sm text-panel-fg-muted">
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
