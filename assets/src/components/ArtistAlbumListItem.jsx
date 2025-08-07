import { formatDuration } from "../utils/formatDuration";
import { splitSongsByDisc } from "../utils/splitSongsByDisc";

const createAudio = () => {
  const audioEl = document.createElement("audio");
  audioEl.playsinline = true;
  document.body.appendChild(audioEl);
  return audioEl;
};

const playSong = (id) => {
  let audioEl = document.querySelector("audio");
  if (!audioEl) audioEl = createAudio();
  audioEl.src = `/stream/${id}`;
  audioEl.play();
};

export function ArtistAlbumListItem({ album }) {
  const albumDiscs = splitSongsByDisc(album.songs);

  return (
    <div class="flex w-full">
      <div class="flex-shrink-0 pr-18 text-sm w-80">
        <div class="aspect-square w-full bg-stone-200 mb-4 shadow-lg"></div>
        <h3 class="font-semibold">{album.name}</h3>
        <span class="text-stone-500">{album.release_year}</span>
      </div>
      <div class="space-y-6 w-full">
        {albumDiscs.map((disc) => (
          <div key={`${album.id}-disc-${disc.number}`}>
            {albumDiscs.length > 1 ? (
              <h3
                key={`${album.id}-disc-label-${disc.number}`}
                class="text-xs text-stone-500 font-semibold mb-2"
              >
                Disc {disc.number}
              </h3>
            ) : null}
            <ul class="space-y-2 text-sm">
              {disc.songs.map((song) => (
                <li
                  key={song.id}
                  class="relative flex justify-between"
                  onClick={() => playSong(song.id)}
                  onKeyDown={() => playSong(song.id)}
                >
                  {song.track ? (
                    <span class="absolute right-full text-right mr-2 text-stone-500">
                      {song.track}.
                    </span>
                  ) : null}
                  <span>{song.name}</span>
                  <span class="tabular-nums">
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
