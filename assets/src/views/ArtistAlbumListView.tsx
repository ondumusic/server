import { useParams } from "react-router";
import { ArtistAlbumListHeader } from "../components/ArtistAlbumListHeader";
import { ArtistAlbumListItem } from "../components/ArtistAlbumListItem";
import { useAlbumArtistQuery } from "../hooks/useAlbumArtistQuery";
import { useInfiniteArtistAlbumsQuery } from "../hooks/useInfiniteArtistAlbumsQuery";
import type { Album, UUID } from "../types";
import { paginatedMap } from "../utils/paginatedMap";

type Params = { artistId: UUID };

export function ArtistAlbumListView() {
  const { artistId } = useParams() as Params;

  const {
    isFetching: isFetchingArtist,
    data: dataArtist,
    error: errorArtist,
  } = useAlbumArtistQuery({ artistId });

  const { isFetching, hasFirstPage, data, error } =
    useInfiniteArtistAlbumsQuery(
      {
        artistId: dataArtist?.id,
      },
      {
        enabled: !!dataArtist,
      },
    );

  if ((isFetching || isFetchingArtist) && !hasFirstPage) return "Loading...";
  if (errorArtist) throw errorArtist;
  if (error) throw error;
  if (!dataArtist) return;

  return (
    <div className="space-y-8 mx-8 my-8">
      <ArtistAlbumListHeader albumArtist={dataArtist} />
      <div className="space-y-16">
        {paginatedMap<Album>(data, (album) => (
          <ArtistAlbumListItem
            key={album.id}
            albumArtist={dataArtist}
            album={album}
          />
        ))}
      </div>
    </div>
  );
}
