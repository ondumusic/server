import i18next from "../i18next";
import type { Track } from "../types";

export function formatTotalDuration(tracks: Track[]): string {
  const totalDuration = tracks.reduce(
    (total, { duration }) => total + duration,
    0,
  );
  const hours = Math.floor(totalDuration / 3600);
  const minutes = Math.floor((totalDuration % 3600) / 60);
  if (hours === 0) {
    return i18next.t("formattedDuration.minutes", {
      defaultValue: "{{ count }} minutes",
      count: minutes,
    });
  }

  if (minutes === 0) {
    return i18next.t("formattedDuration.hours", {
      defaultValue: "{{ count }} hours",
      count: hours,
    });
  }

  return i18next.t("formattedDuration.hoursAndMinutes", {
    defaultValue:
      '{{ count }} hours, $t(formattedDuration.minutes, {"count": {{ minutes }}})',
    count: hours,
    minutes,
  });
}
