type SingleValueOp = "=" | "!=" | ">" | ">=" | "<" | "<=";
type RangeOp = "between" | "betweenExclusive";
export type QueryOperation = SingleValueOp | RangeOp;

type QueryCondition<T> = {
  [K in keyof T & string]:
    | [field: K, op: SingleValueOp, value: T[K]]
    | [field: K, op: RangeOp, lower: T[K], upper: T[K]];
}[keyof T & string];

export type Query<T, I> = {
  whereIndex?: QueryCondition<I>;
  having?: {
    [K in keyof T]?:
      | [op: SingleValueOp, value: T[K]]
      | [op: RangeOp, lower: T[K], upper: T[K]]
      | ((value: T[K]) => boolean);
  };
  sortBy?: keyof T & string;
  sortDir?: "asc" | "desc";
};

export type Comparable = number | string | Date;

export function compare(a: unknown, b: unknown): number {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  const x = a as Comparable;
  const y = b as Comparable;
  if (x < y) return -1;
  if (x > y) return 1;
  return 0;
}

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
