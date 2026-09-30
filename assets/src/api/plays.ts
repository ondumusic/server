import { client, type RequestOptions } from "./client";

export type Play = {
  id: string;
  trackId: string;
  playedAt: string;
};

type RecordPlaysResponse = { ok: true } | { error: string };

export const playApi = {
  record(plays: Play[], opts?: RequestOptions) {
    return client.post<{ plays: Play[] }, RecordPlaysResponse>(
      "/plays",
      { plays },
      opts,
    );
  },
};
