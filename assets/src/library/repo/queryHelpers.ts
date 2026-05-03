import type { IndexesOf, JoinsOf, UUID } from "../../types";

type SingleValueOp = "=" | "!=" | ">" | ">=" | "<" | "<=";
type RangeOp = "between" | "betweenExclusive";
type ListOp = "in";
export type QueryOperation = SingleValueOp | RangeOp | ListOp;
export type EntityOf<J> = J extends { entity: infer E } ? E : never;

type QueryCondition<T> = {
  [K in keyof T & string]:
    | [field: K, op: SingleValueOp, value: T[K]]
    | [field: K, op: RangeOp, lower: T[K], upper: T[K]]
    | [field: K, op: ListOp, values: T[K][]];
}[keyof T & string];

export type SortField<T> =
  | (keyof T & string)
  | [keyof T & string, "asc" | "desc"]
  | "random";

export type JoinDescriptor<T, P> = {
  store: string;
  cardinality: "one" | "many";
  foreignKey?: keyof P & string;
  references?: keyof T & string;
  query: (parents: P[]) => Omit<Query<T>, "join">;
  join?: {
    [K in keyof JoinsOf<T>]?: JoinDescriptor<EntityOf<JoinsOf<T>[K]>, T>;
  };
};

export type Query<T> = {
  whereIndex?: QueryCondition<IndexesOf<T> & { id: UUID }>;
  having?: {
    [K in keyof T]?:
      | [op: SingleValueOp, value: T[K]]
      | [op: RangeOp, lower: T[K], upper: T[K]]
      | [op: ListOp, values: T[K][]]
      | ((value: T[K]) => boolean);
  };
  join?: {
    [K in keyof JoinsOf<T>]?: JoinDescriptor<EntityOf<JoinsOf<T>[K]>, T>;
  };
  sortBy?: SortField<T> | SortField<T>[];
  sortDir?: "asc" | "desc";
};

export type JoinQuery<T, P> = Query<T> & {
  store: string;
  cardinality: "one" | "many";
  foreignKey?: keyof P & string;
  references?: keyof T & string;
};

export type RangeQuery =
  | { kind: "range"; range: IDBKeyRange | null }
  | { kind: "in"; keys: IDBValidKey[] };

export type Comparable = number | string | Date;

export const collectStores = <T>(
  rootStore: string,
  query: Query<T>,
): string[] => {
  const stores = new Set<string>([rootStore]);

  const visit = (joins: Query<T>["join"] | undefined) => {
    if (!joins) return;
    const descriptors = Object.values(joins) as Array<
      JoinDescriptor<unknown, unknown> | undefined
    >;
    for (const desc of descriptors) {
      if (!desc) continue;
      stores.add(desc.store);
      visit(desc.join as Query<T>["join"] | undefined);
    }
  };

  visit(query.join);
  return Array.from(stores);
};

export const usesIdRange = <T>(
  q: Query<T>,
  keyPath: string | string[],
): boolean => {
  if (!q.whereIndex) return false;
  if (q.having && Object.keys(q.having).length > 0) return false;
  if (q.sortBy) return false;
  if (typeof keyPath !== "string") return false;
  const [field, op] = q.whereIndex as [string, QueryOperation, ...unknown[]];
  return field === keyPath && op === "in";
};

export const opToRange = (
  op: QueryOperation,
  ...args: unknown[]
): RangeQuery => {
  switch (op) {
    case "=":
      return { kind: "range", range: IDBKeyRange.only(args[0]) };
    case ">":
      return { kind: "range", range: IDBKeyRange.lowerBound(args[0], true) };
    case ">=":
      return { kind: "range", range: IDBKeyRange.lowerBound(args[0], false) };
    case "<":
      return { kind: "range", range: IDBKeyRange.upperBound(args[0], true) };
    case "<=":
      return { kind: "range", range: IDBKeyRange.upperBound(args[0], false) };
    case "in":
      return { kind: "in", keys: args[0] as IDBValidKey[] };
    case "between":
      return {
        kind: "range",
        range: IDBKeyRange.bound(args[0], args[1], false, false),
      };
    case "betweenExclusive":
      return {
        kind: "range",
        range: IDBKeyRange.bound(args[0], args[1], true, true),
      };
    // case "between[)":
    //   return { kind: "range", range: IDBKeyRange.bound(args[0], args[1], false, true) } // left inclusive
    // case "between(]":
    //   return { kind: "range", range: IDBKeyRange.bound(args[0], args[1], true, false) } // right inclusive
    default:
      return { kind: "range", range: null };
  }
};

export const applyOp = (a: unknown, op: QueryOperation, ...args: unknown[]) => {
  const x = a as Comparable;
  const y = args[0] as Comparable;
  const z = args[1] as Comparable;

  switch (op) {
    case "=":
      return a === args[0];
    case "!=":
      return a !== args[0];
    case ">":
      return x > y;
    case ">=":
      return x >= y;
    case "<":
      return x < y;
    case "<=":
      return x <= y;
    case "in":
      return (args[0] as unknown[]).includes(a);
    case "between":
      return x >= y && x <= z;
    case "betweenExclusive":
      return x > y && x < z;
    default:
      return false;
  }
};
