import { useParams } from "react-router";

export function ArtistAlbumList() {
  const params = useParams();

  return <div>List of albums and songs for artist: {params.artistId}</div>;
}
