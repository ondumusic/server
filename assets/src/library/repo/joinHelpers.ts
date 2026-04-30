import type { JoinsOf, UUID } from "../../types";
import type { Repo } from "../repo";
import type { EntityOf, JoinQuery } from "./queryHelpers";

export const executeJoins = async <T extends { id: UUID }>(
  repo: Repo,
  results: T[],
  join: {
    [K in keyof JoinsOf<T>]?: (ids: T[]) => JoinQuery<EntityOf<JoinsOf<T>[K]>>;
  },
) => {
  const joinEntries = Object.entries(join) as [
    string,
    (items: T[]) => JoinQuery<unknown>,
  ][];

  const joinResults = await Promise.all(
    joinEntries.map(async ([field, buildQuery]) => {
      const {
        store,
        references = "id",
        foreignKey = "id",
        cardinality,
        ...subquery
      } = buildQuery(results);
      const items = (await repo.query(store, subquery)) as Record<
        string,
        unknown
      >[];

      return [field, foreignKey, references, cardinality, items] as const;
    }),
  );

  return results.map((item) => {
    const enriched: Record<string, unknown> = { ...item };
    for (const [
      field,
      foreignKey,
      references,
      cardinality,
      subRows,
    ] of joinResults) {
      console.log(subRows[0], references, item, foreignKey);
      const matches = subRows.filter(
        (sr) => sr[references] === enriched[foreignKey],
      );
      enriched[field] = cardinality === "one" ? (matches[0] ?? null) : matches;
    }
    return enriched as T;
  });
};
