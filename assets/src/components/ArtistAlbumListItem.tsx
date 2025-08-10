import { useMemo } from "react";
import { usePlayer } from "../hooks/usePlayer";
import type { Album, AlbumArtist, Song } from "../types";
import { formatDuration } from "../utils/formatDuration";
import { splitSongsByDisc } from "../utils/splitSongsByDisc";

interface Props {
  album: Album;
  albumArtist: AlbumArtist;
}

export function ArtistAlbumListItem({ album }: Props) {
  const { enqueueAndPlay, currentSong } = usePlayer();

  // For UX we want to split multi-disc albums into separate arrays so we
  // can display them a bit nicer.
  const songsPerDisc = useMemo(
    () => splitSongsByDisc(album.songs),
    [album.songs],
  );

  // Only show song artists if there is more than 1 unique artist
  const shouldShowSongArtist =
    new Set(album.songs.map((song) => song.artist.id)).size > 1;

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
        {songsPerDisc.map((disc) => (
          <div key={`${album.id}-disc-${disc.number}`}>
            {songsPerDisc.length > 1 ? (
              <h3
                key={`${album.id}-disc-label-${disc.number}`}
                className="text-xs text-stone-500 font-semibold mb-2"
              >
                Disc {disc.number}
              </h3>
            ) : null}
            <ul className="space-y-2 text-sm">
              {disc.songs.map((song: Song) => (
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
                  <div>
                    <span
                      className={
                        currentSong && currentSong.id === song.id
                          ? "font-semibold"
                          : ""
                      }
                    >
                      {song.name}
                    </span>
                    {shouldShowSongArtist ? (
                      <span className="block text-stone-400">
                        {song.artist.name}
                      </span>
                    ) : null}
                  </div>
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
