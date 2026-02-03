import type { InfiniteData } from "@tanstack/react-query";
import type { ReactNode } from "react";
import type { Page } from "../types";

type CallbackFn<T, R> = (page: T, entryIndex: number) => R | R[];

export function paginatedMap<T, R = ReactNode>(
  data: InfiniteData<Page<T>> | undefined,
  callback: CallbackFn<T, R>,
): R[] {
  if (!data) return [];
  return data.pages.flatMap((page) => page.entries.flatMap(callback));
}
