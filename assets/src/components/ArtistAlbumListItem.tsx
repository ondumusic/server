import { useMemo } from "react";
import { usePlayer } from "../hooks/usePlayer";
import type { Album, AlbumArtist, Track } from "../types";
import { formatDuration } from "../utils/formatDuration";
import { splitTracksByDisc } from "../utils/splitTracksByDisc";

interface Props {
  album: Album;
  albumArtist: AlbumArtist;
}

export function ArtistAlbumListItem({ album }: Props) {
  const { enqueueAndPlay, currentTrack } = usePlayer();

  // For UX we want to split multi-disc albums into separate arrays so we
  // can display them a bit nicer.
  const tracksPerDisc = useMemo(
    () => splitTracksByDisc(album.tracks),
    [album.tracks],
  );

  // Only show track artists if there is more than 1 unique artist
  const shouldShowTrackArtist =
    new Set(album.tracks.map((track) => track.artist.id)).size > 1;

  return (
    <div className="flex w-full">
      <div className="flex-shrink-0 pr-18 text-sm w-80">
        <button
          type="button"
          className="aspect-square w-full bg-stone-200 mb-4 shadow-lg cursor-pointer hover:bg-emerald-600/50"
          onClick={() => enqueueAndPlay(album.tracks)}
          onKeyDown={() => enqueueAndPlay(album.tracks)}
        ></button>
        <h3 className="font-semibold">{album.name}</h3>
        <span className="text-stone-500">{album.releaseYear}</span>
      </div>
      <div className="space-y-6 w-full">
        {tracksPerDisc.map((disc) => (
          <div key={`${album.id}-disc-${disc.number}`}>
            {tracksPerDisc.length > 1 ? (
              <h3
                key={`${album.id}-disc-label-${disc.number}`}
                className="text-xs text-stone-500 font-semibold mb-2"
              >
                Disc {disc.number}
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
                    <span className="absolute right-full text-right mr-2 text-stone-500">
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
                  <span className="tabular-nums">
                    {formatDuration(track.duration)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </div>
  );
}
