import type { Album, Artist, Playlist, PlaylistItem, Track } from "../types";
import { repo } from "./repo";

export const transforms = {
  async artists(artists: Artist[]) {
    return artists.map((artist) => {
      return {
        id: artist.id,
        name: artist.name,
        sortName: artist.sortName,
        slug: artist.slug,
        albumCount: artist.albumCount,
        insertedAt: new Date(artist.insertedAt as string),

        // TMP VALUES:
        __type: "artist" as const,
        missingData: "NO",
      };
    });
  },

  async albums(albums: Album[]) {
    const artistIds = new Set(albums.map((a) => a.artistId));
    const artists = await repo.getMany<Artist>("artists", [...artistIds]);

    return albums.map((album) => {
      const artist = artists.find((a) => a.id === album.artistId);
      return {
        id: album.id,
        name: album.name,
        sortName: album.sortName,
        slug: album.slug,
        releaseYear: album.releaseYear,
        isUnknown: album.isUnknown,
        artworkUrl: album.artworkUrl,
        insertedAt: new Date(album.insertedAt as string),

        artistId: album.artistId,
        artistName: artist?.name,
        artistSortName: artist?.sortName,

        // TMP VALUES:
        __type: "album" as const,
        tracks: [],
        missingData: !artist ? "YES" : "NO",

        // biome-ignore lint/style/noNonNullAssertion: suppress temporary hack
        artist: artist!,
      };
    });
  },

  async tracks(tracks: Track[]) {
    const artistIds = new Set(tracks.map((t) => t.artistId));
    const albumIds = new Set(tracks.map((t) => t.albumId));

    const artists = await repo.getMany<Artist>("artists", [...artistIds]);
    const albums = await repo.getMany<Album>("albums", [...albumIds]);

    return tracks.map((track) => {
      const artist = artists.find((a) => a.id === track.artistId);
      const album = albums.find((a) => a.id === track.albumId);

      return {
        id: track.id,
        name: track.name,
        disc: track.disc,
        number: track.number,
        duration: track.duration,
        mimetype: track.mimetype,
        streamUrl: track.streamUrl,
        insertedAt: new Date(track.insertedAt as string),

        artistId: track.artistId,
        artistName: artist?.name,
        artistSortName: artist?.sortName,

        albumId: track.albumId,
        albumName: album?.name,
        albumReleaseYear: album?.releaseYear,

        albumArtistId: track.albumArtistId,
        albumArtistName: album?.artistName,
        albumArtistSortName: album?.artistSortName,

        // TMP VALUES:
        __type: "track" as const,
        missingData: !artist || !album ? "YES" : "NO",

        // biome-ignore lint/style/noNonNullAssertion: suppress temporary hack
        artist: artist!,
      };
    });
  },

  async playlists(playlists: Playlist[]) {
    return playlists.map((playlist) => {
      return {
        ...playlist,
        __type: "playlist" as const,
        hasParent: playlist.parentId ? ("YES" as const) : ("NO" as const),
        missingData: "NO",
      };
    });
  },

  async playlistItems(playlistItems: PlaylistItem[]) {
    return playlistItems.map((playlistItem) => {
      return {
        ...playlistItem,
        __type: "playlistItem" as const,
        missingData: "NO",
      };
    });
  },
};
