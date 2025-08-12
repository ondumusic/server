export function formatDuration(seconds: number): string {
  if (!seconds) return "0:00";
  const result = new Date(1000 * seconds).toISOString().substr(11, 8);

  if (result.substr(0, 3) === "00:") {
    return result.substr(3).replace(/^0/, "");
  }
  return result.replace(/^0/, "");
}
