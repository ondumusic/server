import type { IndexesOf, JoinsOf } from "../../types";

type SingleValueOp = "=" | "!=" | ">" | ">=" | "<" | "<=";
type RangeOp = "between" | "betweenExclusive";
export type QueryOperation = SingleValueOp | RangeOp;
export type EntityOf<J> = J extends { entity: infer E } ? E : never;

type QueryCondition<T> = {
  [K in keyof T & string]:
    | [field: K, op: SingleValueOp, value: T[K]]
    | [field: K, op: RangeOp, lower: T[K], upper: T[K]];
}[keyof T & string];

export type SortField<T> =
  | (keyof T & string)
  | [keyof T & string, "asc" | "desc"]
  | "random";

export type Query<T> = {
  whereIndex?: QueryCondition<IndexesOf<T>>;
  having?: {
    [K in keyof T]?:
      | [op: SingleValueOp, value: T[K]]
      | [op: RangeOp, lower: T[K], upper: T[K]]
      | ((value: T[K]) => boolean);
  };
  join?: {
    // Only keys of T that appear in T's Joins map are joinable.
    // The callback returns a Query of the joined entity.
    [K in keyof JoinsOf<T>]?: (ids: T[]) => JoinQuery<EntityOf<JoinsOf<T>[K]>>;
  };
  sortBy?: SortField<T> | SortField<T>[];
  sortDir?: "asc" | "desc";
};

export type JoinQuery<T> = Query<T> & {
  store: string;
  cardinality: "one" | "many";
  foreignKey?: string;
  references?: string;
};

export type Comparable = number | string | Date;

export const opToRange = (op: QueryOperation, ...args: unknown[]) => {
  switch (op) {
    case "=":
      return IDBKeyRange.only(args[0]);
    case ">":
      return IDBKeyRange.lowerBound(args[0], true);
    case ">=":
      return IDBKeyRange.lowerBound(args[0], false);
    case "<":
      return IDBKeyRange.upperBound(args[0], true);
    case "<=":
      return IDBKeyRange.upperBound(args[0], false);
    case "between":
      return IDBKeyRange.bound(args[0], args[1], false, false);
    case "betweenExclusive":
      return IDBKeyRange.bound(args[0], args[1], true, true);
    // case "between[)":
    //   return IDBKeyRange.bound(args[0], args[1], false, true);  // left inclusive
    // case "between(]":
    //   return IDBKeyRange.bound(args[0], args[1], true, false);  // right inclusive
    default:
      return null;
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
    case "between":
      return x >= y && x <= z;
    case "betweenExclusive":
      return x > y && x < z;
    default:
      return false;
  }
};
