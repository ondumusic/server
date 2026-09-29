import type { Album, Artist, UUID } from "../types";
import { client, type RequestOptions } from "./client";

export type IssueCode =
  | "artwork_missing"
  | "artwork_not_square"
  | "artwork_low_res"
  | "album_missing"
  | "release_year_missing"
  | "track_number_missing"
  | "track_number_duplicate"
  | "track_number_gap"
  | "title_missing"
  | "artist_missing";

export interface Issue {
  code: IssueCode;
  details: {
    width?: number;
    height?: number;
    disc?: number;
    numbers?: number[];
    trackIds?: UUID[];
  };
}

export interface AlbumIssues {
  __type: "albumIssues";
  album: Album;
  artist: Artist;
  issues: Issue[];
}

export interface TrackIssues {
  __type: "trackIssues";
  track: { id: UUID; name: string; path: string };
  issues: Issue[];
}

export type IssueEntry = AlbumIssues | TrackIssues;

export const issueApi = {
  async listIssues(opts?: RequestOptions) {
    const entries: IssueEntry[] = [];
    for await (const entry of client.paginate<undefined, IssueEntry>(
      "/issues",
      opts,
    )) {
      entries.push(entry);
    }
    return entries;
  },
};
