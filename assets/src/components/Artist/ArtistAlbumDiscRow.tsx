import { Trans } from "react-i18next";
import type { DiscItem } from "./types";

interface Props {
  item: DiscItem;
}

export function ArtistAlbumDiscRow({ item }: Props) {
  return (
    <div className="font-semibold text-xs text-muted pl-6 @2xl:pl-44 @3xl:pl-62 pb-1">
      <Trans i18nKey="album.discNumber" disc={item.disc.number}>
        Disc {{ disc: item.disc.number }}
      </Trans>
    </div>
  );
}
