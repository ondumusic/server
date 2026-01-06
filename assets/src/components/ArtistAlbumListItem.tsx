import { useMemo } from "react";
import { Trans, useTranslation } from "react-i18next";
import { PlayIcon } from "../components/icons/PlayIcon";
import { usePlayer } from "../hooks/usePlayer";
import { useQueue } from "../hooks/useQueue";
import type { Album, Artist, Track } from "../types";
import { classNames } from "../utils/classNames";
import { formatDuration } from "../utils/formatDuration";
import { formatTotalDuration } from "../utils/formatTotalDuration";
import { splitTracksByDisc } from "../utils/splitTracksByDisc";
import {
  resetAccentColor,
  updateAccentColor,
} from "../utils/updateAccentColor";

interface Props {
  album: Album;
  artist: Artist;
}

export function ArtistAlbumListItem({ album }: Props) {
  const { enqueueAndPlay } = usePlayer();
  const { currentTrack } = useQueue();
  const { t } = useTranslation();

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
      <div className="hidden lg:block flex-shrink-0 pr-18 text-sm w-80">
        <button
          type="button"
          className="relative aspect-square w-full bg-stone-200 mb-4 shadow-xl cursor-pointer rounded-sm overflow-hidden group/cover"
          onClick={(e) => {
            e.preventDefault();
            if (!(e.target instanceof HTMLElement)) return;
            const img = e.target.closest("button")?.querySelector("img");

            enqueueAndPlay(album.tracks);
            if (img) updateAccentColor(img);
            else resetAccentColor();
          }}
          onKeyDown={() => enqueueAndPlay(album.tracks)}
        >
          {album.artworkUrl && (
            <img
              src={album.artworkUrl}
              alt=""
              className="w-full h-full object-cover object-center"
            />
          )}

          {/*<div className="absolute w-full h-full top-0 left-0 content-center bg-black opacity-0 transition-opacity group-hover/cover:opacity-30">
            <PlayIcon
              className="absolute size-20 text-white top-1/2 -translate-y-1/2 left-1/2 -translate-x-1/2"
              title={t("button.playSelectedTrack", {
                defaultValue: "Play {{ albumName }}",
                albumName: album.name,
              })}
            />
          </div>*/}
        </button>

        <div className="mt-4 flex flex-wrap gap-2">
          <div className="aspect-square w-6 bg-accent-50"></div>
          <div className="aspect-square w-6 bg-accent-100"></div>
          <div className="aspect-square w-6 bg-accent-200"></div>
          <div className="aspect-square w-6 bg-accent-300"></div>
          <div className="aspect-square w-6 bg-accent-400"></div>
          <div className="aspect-square w-6 bg-accent-500"></div>
          <div className="aspect-square w-6 bg-accent-600"></div>
          <div className="aspect-square w-6 bg-accent-700"></div>
          <div className="aspect-square w-6 bg-accent-800"></div>
          <div className="aspect-square w-6 bg-accent-900"></div>
          <div className="aspect-square w-6 bg-accent-950"></div>
        </div>

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
              <ul className="text-sm">
                {disc.tracks.map((track: Track) => (
                  <li
                    key={track.id}
                    className="relative py-1.5 flex justify-between cursor-pointer group/song"
                    onClick={() => enqueueAndPlay(album.tracks, track)}
                    onKeyDown={() => enqueueAndPlay(album.tracks, track)}
                  >
                    {track.number ? (
                      <div className="absolute right-full text-right mr-2">
                        <span className="text-stone-400 font-light group-hover/song:hidden">
                          {track.number}.
                        </span>
                        <div className="hidden group-hover/song:block py-1 text-accent-600">
                          <PlayIcon
                            className="size-4"
                            title={t("button.playSelectedTrack", {
                              defaultValue: "Play {{ trackName }}",
                              trackName: track.name,
                            })}
                          />
                        </div>
                      </div>
                    ) : null}
                    <div className="mr-2">
                      <span
                        className={classNames([
                          currentTrack &&
                            currentTrack.id === track.id &&
                            "font-semibold",
                        ])}
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
