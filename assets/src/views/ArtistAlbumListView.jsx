import { useParams } from "react-router";
import { ArtistAlbumListHeader } from "../components/ArtistAlbumListHeader";
import { ArtistAlbumListItem } from "../components/ArtistAlbumListItem";
import { useArtistQuery } from "../hooks/useArtistQuery";
import { useInfiniteArtistAlbumsQuery } from "../hooks/useInfiniteArtistAlbumsQuery";
import { paginatedMap } from "../utils/paginatedMap";

export function ArtistAlbumListView() {
  const { artistId } = useParams();

  const { isFetching: isFetchingArtist, data: dataArtist } = useArtistQuery({
    artistId: artistId,
  });

  const { isFetching, hasFirstPage, data, error } =
    useInfiniteArtistAlbumsQuery({
      artistId: artistId,
    });

  if ((isFetching || isFetchingArtist) && !hasFirstPage) return "Loading...";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <div className="space-y-8 mx-8 my-8">
      {!isFetchingArtist && dataArtist ? (
        <ArtistAlbumListHeader artist={dataArtist} />
      ) : null}
      {paginatedMap(data, (album) => (
        <ArtistAlbumListItem key={album.id} album={album} />
      ))}
    </div>
  );
}
