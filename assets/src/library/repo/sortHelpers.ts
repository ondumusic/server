import type { Comparable, SortField } from "./queryHelpers";

function compare(a: unknown, b: unknown): number {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  const x = a as Comparable;
  const y = b as Comparable;
  if (x < y) return -1;
  if (x > y) return 1;
  return 0;
}

export const executeSort = <T>(
  results: T[],
  sortBy: SortField<T> | SortField<T>[],
  sortDir: "asc" | "desc",
) => {
  // Normalize to an array of entries.
  // A tuple like ["year", "desc"] is itself an array, so we detect it
  // by checking if the second element is a direction string.
  const isSingleTuple =
    Array.isArray(sortBy) &&
    sortBy.length === 2 &&
    (sortBy[1] === "asc" || sortBy[1] === "desc");

  const entries: SortField<T>[] =
    typeof sortBy === "string"
      ? [sortBy]
      : isSingleTuple
        ? [sortBy as SortField<T>]
        : (sortBy as SortField<T>[]);

  const compareFns = entries.map((entry) => {
    const [field, dir] = Array.isArray(entry) ? entry : [entry, sortDir];
    const mult = dir === "desc" ? -1 : 1;
    return (a: T, b: T) =>
      compare(
        (a as Record<string, unknown>)[field],
        (b as Record<string, unknown>)[field],
      ) * mult;
  });

  results.sort((a, b) => {
    for (const fn of compareFns) {
      const r = fn(a, b);
      if (r !== 0) return r;
    }
    return 0;
  });
};
