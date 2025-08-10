import { useQuery } from "@tanstack/react-query";
import { api } from "../services/api";
import type { UUID } from "../types";

interface Params {
  albumArtistId: UUID;
}

export function useAlbumArtistQuery({ albumArtistId }: Params) {
  return useQuery({
    queryKey: ["albumArtist", albumArtistId],
    queryFn: () => api.get(`/artists/${albumArtistId}`),
  });
}
