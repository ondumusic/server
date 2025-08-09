import { useParams } from "react-router";
import { ArtistAlbumListHeader } from "../components/ArtistAlbumListHeader";
import { ArtistAlbumListItem } from "../components/ArtistAlbumListItem";
import { useAlbumArtistQuery } from "../hooks/useAlbumArtistQuery";
import { useInfiniteArtistAlbumsQuery } from "../hooks/useInfiniteArtistAlbumsQuery";
import { paginatedMap } from "../utils/paginatedMap";

export function ArtistAlbumListView() {
  const { albumArtistId } = useParams();

  const { isFetching: isFetchingArtist, data: dataArtist } =
    useAlbumArtistQuery({
      albumArtistId: albumArtistId,
    });

  const { isFetching, hasFirstPage, data, error } =
    useInfiniteArtistAlbumsQuery(
      {
        albumArtistId: dataArtist?.id,
      },
      {
        enabled: !!dataArtist,
      },
    );

  if ((isFetching || isFetchingArtist) && !hasFirstPage) return "Loading...";
  if (error) return `An error has occurred: ${error.message}`;

  return (
    <div className="space-y-8 mx-8 my-8">
      <ArtistAlbumListHeader albumArtist={dataArtist} />
      {paginatedMap(data, (album) => (
        <ArtistAlbumListItem
          key={album.id}
          albumArtist={dataArtist}
          album={album}
        />
      ))}
    </div>
  );
}
