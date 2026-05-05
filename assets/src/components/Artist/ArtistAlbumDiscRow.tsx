import { Trans } from "react-i18next";
import type { DiscItem } from "./types";

interface Props {
  item: DiscItem;
}

export function ArtistAlbumDiscRow({ item }: Props) {
  return (
    <div className="font-semibold text-xs text-gray-500 pl-6 @md:pl-44 @xl:pl-60 pb-1">
      <Trans i18nKey="album.discNumber" disc={item.disc.number}>
        Disc {{ disc: item.disc.number }}
      </Trans>
    </div>
  );
}
