import { useQuery } from "@tanstack/react-query";
import { api } from "../services/api";
import type { Artist, UUID } from "../types";

interface Params {
  artistId: UUID;
}

type Request = undefined;
type Response = Artist;

export function useArtistQuery({ artistId }: Params) {
  return useQuery({
    queryKey: ["artist", artistId],
    queryFn: () => api.get<Request, Response>(`/artists/${artistId}`),
  });
}
