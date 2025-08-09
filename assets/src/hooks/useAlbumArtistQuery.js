import { useQuery } from "@tanstack/react-query";
import { api } from "../services/api";

export function useAlbumArtistQuery({ albumArtistId }) {
  return useQuery({
    queryKey: ["albumArtist", albumArtistId],
    queryFn: () => api.get(`/artists/${albumArtistId}`),
  });
}
