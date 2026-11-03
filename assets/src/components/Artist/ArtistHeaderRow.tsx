import { Trans } from "react-i18next";
import { useFileDrop } from "../../hooks/useFileDrop";
import { artworkUrl } from "../../utils/artwork";
import { classNames } from "../../utils/classNames";
import { ArtistArtwork } from "../ArtistArtwork";
import { SpinnerIcon } from "../icons/SpinnerIcon";
import { PlayShuffleButtons } from "../PlayShuffleButtons";
import type { ArtistItem } from "./types";

interface Props {
  item: ArtistItem;
  onDropArtwork: (file: File) => void;
  isUpdatingArtwork?: boolean;
}

export function ArtistHeaderRow({
  item,
  onDropArtwork,
  isUpdatingArtwork,
}: Props) {
  const { artist } = item;
  const hasArtwork = !!artworkUrl(artist);
  const { isDraggingFiles, props: dropProps } = useFileDrop(onDropArtwork);

  // We only want to show the ArtistArtwork when it exists, or during
  // file drag, of upload events.
  const showArtwork = hasArtwork || isDraggingFiles || isUpdatingArtwork;

  return (
    <header
      className={classNames([
        "mt-4 lg:mt-5 @md:pb-8 flex gap-6",
        showArtwork ? "items-center" : "items-end justify-between",
      ])}
      {...dropProps}
    >
      {showArtwork && (
        <div className="w-36 flex-shrink-0">
          <ArtistArtwork
            artist={artist}
            size="large"
            className="w-full aspect-square rounded-full"
          >
            {isUpdatingArtwork ? (
              <div className="absolute inset-0 flex items-center justify-center rounded-full bg-black/40 text-white">
                <SpinnerIcon className="size-8 animate-spin" title="" />
              </div>
            ) : (
              isDraggingFiles && (
                <>
                  {hasArtwork && (
                    <div className="absolute inset-0 rounded-full bg-black/30" />
                  )}
                  <div className="absolute inset-0 rounded-full border border-dashed border-accent-500" />
                </>
              )
            )}
          </ArtistArtwork>
        </div>
      )}

      <div className="min-w-0">
        <h1
          className="font-semibold text-4xl lg:text-2xl line-clamp-1"
          title={artist.name}
        >
          {artist.name}
        </h1>
        <span className="text-sm text-page-fg-muted">
          <Trans i18nKey="artist.albumCount" count={artist.albumCount}>
            {{ count: artist.albumCount }} albums
          </Trans>
        </span>

        {showArtwork && (
          <PlayShuffleButtons
            input={{ artistId: artist.id }}
            className="mt-3"
          />
        )}
      </div>

      {!showArtwork && (
        <PlayShuffleButtons
          input={{ artistId: artist.id }}
          className="flex-shrink-0"
        />
      )}
    </header>
  );
}
