export function ArtistAlbumListHeader({ artist }) {
  return (
    <header class="pb-4 border-b border-stone-300">
      <h1 class="font-semibold text-2xl">{artist.name}</h1>
      <span class="text-sm text-stone-400">{artist.album_count} albums</span>
    </header>
  );
}
