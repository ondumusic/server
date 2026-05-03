import type { UUID } from "../../types";
import type { Repo } from "../repo";
import type { JoinDescriptor, Query } from "./queryHelpers";

export const executeJoins = async <T>(
  repo: Repo,
  results: T[],
  joins: NonNullable<Query<T>["join"]>,
  tx: IDBTransaction,
) => {
  const entries = Object.entries(joins) as [
    string,
    JoinDescriptor<unknown, T>,
  ][];

  const joinResults = await Promise.all(
    entries.map(async ([field, descriptor]) => {
      const query: Query<unknown> = {
        ...descriptor.query(results),
        join: descriptor.join,
      };

      const items = (await repo.query(
        descriptor.store,
        query as Query<{ id: UUID }>,
        tx,
      )) as Record<string, unknown>[];

      return [
        field,
        descriptor.foreignKey ?? "id",
        descriptor.references ?? "id",
        descriptor.cardinality,
        items,
      ] as const;
    }),
  );

  return results.map((item) => {
    const enriched = { ...item } as Record<string, unknown>;

    for (const [
      field,
      foreignKey,
      references,
      cardinality,
      rows,
    ] of joinResults) {
      const matches = rows.filter(
        (sr) => sr[references] === enriched[foreignKey],
      );
      enriched[field] = cardinality === "one" ? (matches[0] ?? null) : matches;
    }
    return enriched as T;
  });
};
