import type { ReactNode } from "react";
import type { Page } from "../types";

interface Data<T> {
  pages: Page<T>[];
}

type CallbackFn<T, R> = (page: T) => R;

export function paginatedMap<T, R = ReactNode>(
  data: Data<T> | undefined,
  callback: CallbackFn<T, R>,
): R[] {
  if (!data) return [];
  return data.pages.flatMap((page) => page.entries.flatMap(callback));
}
