import { notifyChanges } from "../events";
import { repo } from "../repo";
import { searchTokens, searchTokensVersion } from "./tokens";

const META_KEY = "searchTokens-version";

const tokenizers = {
  artists: searchTokens.artist,
  albums: searchTokens.album,
  tracks: searchTokens.track,
} as const;

type Tokenizable = {
  name: string;
  searchTokens?: string[];
};

function sameTokens(current: string[] | undefined, next: string[]) {
  if (!current) return false;
  if (current.length !== next.length) return false;
  return current.every((token, i) => token === next[i]);
}

export async function maybeReindexSearch() {
  // We check the meta store for the current search token version number,
  // if it does not exist or is older than desired we will update all
  // search tokens in the database.
  const meta = await repo.get<{ value: number }>("meta", META_KEY);
  if ((meta?.value ?? 0) >= searchTokensVersion) return;

  for (const [store, tokenize] of Object.entries(tokenizers)) {
    await repo.updateEach<Tokenizable>(store, (record) => {
      const tokens = tokenize(record);
      if (sameTokens(record.searchTokens, tokens)) return;
      return { ...record, searchTokens: tokens };
    });
  }

  // Remember where we are and notify the stores of all changes
  await repo.put("meta", { key: META_KEY, value: searchTokensVersion });
  notifyChanges(Object.keys(tokenizers));
}
