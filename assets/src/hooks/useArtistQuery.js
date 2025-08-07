import { useQuery } from "@tanstack/react-query";
import { api } from "../services/api";

export function useArtistQuery({ artistId }) {
  return useQuery({
    queryKey: ["artist", artistId],
    queryFn: () => api.get(`/artists/${artistId}`),
  });
}
