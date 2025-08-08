import { useMemo } from "react";
import { usePlayer } from "../hooks/usePlayer";
import { formatDuration } from "../utils/formatDuration";
import { splitSongsByDisc } from "../utils/splitSongsByDisc";

export function ArtistAlbumListItem({ album }) {
  const { playSong, currentSong } = usePlayer();
  const albumDiscs = useMemo(
    () => splitSongsByDisc(album.songs),
    [album.songs],
  );

  return (
    <div className="flex w-full">
      <div className="flex-shrink-0 pr-18 text-sm w-80">
        <div className="aspect-square w-full bg-stone-200 mb-4 shadow-lg"></div>
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
                  onClick={() => playSong(song)}
                  onKeyDown={() => playSong(song)}
                >
                  {song.track ? (
                    <span className="absolute right-full text-right mr-2 text-stone-500">
                      {song.track}.
                    </span>
                  ) : null}
                  <span
                    className={
                      currentSong.id === song.id ? "font-semibold" : ""
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
