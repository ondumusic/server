export function classNames(
  classes: Array<undefined | null | string | boolean | string[]>,
): string {
  return classes
    .flat()
    .filter((x) => typeof x === "string")
    .map((s) => s.trim())
    .join(" ");
}
