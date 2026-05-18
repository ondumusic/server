export function formatStat(n: number) {
  // Millions
  if (n >= 1_000_000) {
    const m = Math.round(n / 100_000) / 10;
    return `${new Intl.NumberFormat().format(m)}m`;
  }

  // Thousands
  if (n >= 10_000) {
    const k = Math.round(n / 1000);
    return `${new Intl.NumberFormat().format(k)}k`;
  }

  return new Intl.NumberFormat().format(n);
}
