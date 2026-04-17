import type { JoinsOf, UUID } from "../../types";
import type { Repo } from "../repo";
import type { EntityOf, JoinQuery } from "./queryHelpers";

export const executeJoins = async <T extends { id: UUID }>(
  repo: Repo,
  results: T[],
  join: {
    [K in keyof JoinsOf<T>]?: (
      ids: Set<UUID>,
    ) => JoinQuery<EntityOf<JoinsOf<T>[K]>>;
  },
) => {
  const ids = new Set(results.map((i) => i.id));

  const joinEntries = Object.entries(join) as [
    string,
    (ids: Set<UUID>) => JoinQuery<unknown>,
  ][];

  const joinResults = await Promise.all(
    joinEntries.map(async ([key, buildQuery]) => {
      const { store, foreignKey, cardinality, ...subquery } = buildQuery(ids);
      const items = (await repo.query(store, subquery)) as Record<
        string,
        unknown
      >[];
      return [key, foreignKey, cardinality, items] as const;
    }),
  );

  return results.map((item) => {
    const enriched: Record<string, unknown> = { ...item };
    for (const [key, foreignKey, cardinality, subRows] of joinResults) {
      const matches = subRows.filter((sr) => sr[foreignKey] === item.id);
      enriched[key] = cardinality === "one" ? (matches[0] ?? null) : matches;
    }
    return enriched as T;
  });
};
