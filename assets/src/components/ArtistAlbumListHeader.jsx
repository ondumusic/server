export function ArtistAlbumListHeader({ albumArtist }) {
  return (
    <header className="pb-4 border-b border-stone-300">
      <h1 className="font-semibold text-2xl">{albumArtist.name}</h1>
      <span className="text-sm text-stone-400">
        {albumArtist.albumCount} albums
      </span>
    </header>
  );
}
