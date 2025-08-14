import { useMemo } from "react";
import { Trans } from "react-i18next";
import { usePlayer } from "../hooks/usePlayer";
import { useQueue } from "../hooks/useQueue";
import type { Album, AlbumArtist, Track } from "../types";
import { formatDuration } from "../utils/formatDuration";
import { formatTotalDuration } from "../utils/formatTotalDuration";
import { splitTracksByDisc } from "../utils/splitTracksByDisc";

interface Props {
  album: Album;
  albumArtist: AlbumArtist;
}

export function ArtistAlbumListItem({ album }: Props) {
  const { enqueueAndPlay } = usePlayer();
  const { currentTrack } = useQueue();

  // For UX we want to split multi-disc albums into separate arrays so we
  // can display them a bit nicer.
  const tracksPerDisc = useMemo(
    () => splitTracksByDisc(album.tracks),
    [album.tracks],
  );

  // Only show track artists if there is more than 1 unique artist
  const shouldShowTrackArtist =
    new Set(album.tracks.map((track) => track.artist.id)).size > 1;

  const totalFormattedDuration = formatTotalDuration(album.tracks);

  return (
    <div className="flex w-full">
      <div className="flex-shrink-0 pr-18 text-sm w-80">
        <button
          type="button"
          className="aspect-square w-full bg-stone-200 mb-4 shadow-lg cursor-pointer hover:bg-emerald-600/50"
          onClick={() => enqueueAndPlay(album.tracks)}
          onKeyDown={() => enqueueAndPlay(album.tracks)}
        ></button>
        <span className="font-light text-stone-400">
          <Trans
            i18nKey="album.trackCount"
            count={album.tracks.length}
            duration={totalFormattedDuration}
          >
            {{ count: album.tracks.length }} tracks,{" "}
            {{ duration: totalFormattedDuration }}
          </Trans>
        </span>
      </div>
      <div className="w-full">
        <div className="text-sm border-b border-stone-300 pb-2 mb-6">
          <h2 className="font-semibold text-lg">{album.name}</h2>
          <span className="text-stone-400 font-normal">
            {album.releaseYear}
          </span>
        </div>
        <div>
          {tracksPerDisc.map((disc) => (
            <div key={`${album.id}-disc-${disc.number}`}>
              {tracksPerDisc.length > 1 ? (
                <h3
                  key={`${album.id}-disc-label-${disc.number}`}
                  className="text-xs text-stone-500 font-semibold mb-2"
                >
                  <Trans i18nKey="album.discNumber" disc={disc.number}>
                    Disc {{ disc: disc.number }}
                  </Trans>
                </h3>
              ) : null}
              <ul className="space-y-2 text-sm">
                {disc.tracks.map((track: Track) => (
                  <li
                    key={track.id}
                    className="relative flex justify-between"
                    onClick={() => enqueueAndPlay(album.tracks, track)}
                    onKeyDown={() => enqueueAndPlay(album.tracks, track)}
                  >
                    {track.number ? (
                      <span className="absolute right-full text-right mr-2 text-stone-400 font-light">
                        {track.number}.
                      </span>
                    ) : null}
                    <div>
                      <span
                        className={
                          currentTrack && currentTrack.id === track.id
                            ? "font-semibold"
                            : ""
                        }
                      >
                        {track.name}
                      </span>
                      {shouldShowTrackArtist ? (
                        <span className="block text-stone-400">
                          {track.artist.name}
                        </span>
                      ) : null}
                    </div>
                    <span className="tabular-nums text-stone-400 font-light">
                      {formatDuration(track.duration)}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
