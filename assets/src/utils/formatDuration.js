export function formatDuration(seconds) {
  if (!seconds) return "00:00";
  return new Date(1000 * seconds).toISOString().substr(14, 5);
}
