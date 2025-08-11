import { useQuery } from "@tanstack/react-query";
import { api } from "../services/api";
import type { UUID } from "../types";

interface Params {
  artistId: UUID;
}

export function useAlbumArtistQuery({ artistId }: Params) {
  return useQuery({
    queryKey: ["albumArtist", artistId],
    queryFn: () => api.get(`/artists/${artistId}`),
  });
}
