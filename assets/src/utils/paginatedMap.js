export function paginatedMap({ pages = [] }, callback) {
  return pages.map((page) => page.entries.map(callback));
}
