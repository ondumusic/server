import type { ReactNode } from "react";
import type { Page } from "../types";

interface Data<T> {
  pages: Page<T>[];
}

type CallbackFn<T> = (page: T) => ReactNode;

export function paginatedMap<T>(
  data: Data<T> | undefined,
  callback: CallbackFn<T>,
): ReactNode {
  if (!data) return [];
  return data.pages.map((page) => page.entries.map(callback));
}
