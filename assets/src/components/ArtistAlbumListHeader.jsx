export function ArtistAlbumListHeader({ artist }) {
  return (
    <header className="pb-4 border-b border-stone-300">
      <h1 className="font-semibold text-2xl">{artist.name}</h1>
      <span className="text-sm text-stone-400">
        {artist.album_count} albums
      </span>
    </header>
  );
}
