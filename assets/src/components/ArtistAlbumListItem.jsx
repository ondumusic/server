import { useMemo } from "react";
import { usePlayer } from "../hooks/usePlayer";
import { formatDuration } from "../utils/formatDuration";
import { splitSongsByDisc } from "../utils/splitSongsByDisc";

export function ArtistAlbumListItem({ album }) {
  const { enqueueAndPlay, currentSong } = usePlayer();

  // For UX we want to split multi-disc albums into separate arrays so we
  // can display them a bit nicer.
  const albumDiscs = useMemo(
    () => splitSongsByDisc(album.songs),
    [album.songs],
  );

  return (
    <div className="flex w-full">
      <div className="flex-shrink-0 pr-18 text-sm w-80">
        <button
          type="button"
          className="aspect-square w-full bg-stone-200 mb-4 shadow-lg cursor-pointer hover:bg-emerald-600/50"
          onClick={() => enqueueAndPlay(album.songs)}
          onKeyDown={() => enqueueAndPlay(album.songs)}
        ></button>
        <h3 className="font-semibold">{album.name}</h3>
        <span className="text-stone-500">{album.releaseYear}</span>
      </div>
      <div className="space-y-6 w-full">
        {albumDiscs.map((disc) => (
          <div key={`${album.id}-disc-${disc.number}`}>
            {albumDiscs.length > 1 ? (
              <h3
                key={`${album.id}-disc-label-${disc.number}`}
                className="text-xs text-stone-500 font-semibold mb-2"
              >
                Disc {disc.number}
              </h3>
            ) : null}
            <ul className="space-y-2 text-sm">
              {disc.songs.map((song) => (
                <li
                  key={song.id}
                  className="relative flex justify-between"
                  onClick={() => enqueueAndPlay(album.songs, song)}
                  onKeyDown={() => enqueueAndPlay(album.songs, song)}
                >
                  {song.track ? (
                    <span className="absolute right-full text-right mr-2 text-stone-500">
                      {song.track}.
                    </span>
                  ) : null}
                  <span
                    className={
                      currentSong && currentSong.id === song.id
                        ? "font-semibold"
                        : ""
                    }
                  >
                    {song.name}
                  </span>
                  <span className="tabular-nums">
                    {formatDuration(song.duration)}
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
