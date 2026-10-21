import { useEffect, useState } from "react";
import { useQueue } from "../hooks/useQueue";
import { useAlbum } from "../library";
import { artworkUrl } from "../utils/artwork";
import { classNames } from "../utils/classNames";

// Same as the iOS and macOS app we'll use a blurred version of the album
// artwork as the background for things like the mini player.
export function BlurredArtwork() {
  const { currentTrack } = useQueue();
  const { data: album, loading } = useAlbum(currentTrack?.albumId);
  const url = artworkUrl(album);

  // If the current album data is still loading we don't have the artwork url
  // yet. This means it would transition into the placeholder and then into
  // the actual artwork once loaded. It looked ugly so we skip the transition
  // while loading now.
  const isLoadingAlbum = !!currentTrack?.albumId && loading;

  const [imageUrls, setImageUrls] = useState<(string | undefined)[]>(
    isLoadingAlbum ? [] : [url],
  );

  // Only keep the previous image to fade from
  useEffect(() => {
    if (isLoadingAlbum) return;

    setImageUrls((imageUrls) => {
      if (imageUrls.at(-1) === url) return imageUrls;
      return [...imageUrls.slice(-1), url];
    });
  }, [url, isLoadingAlbum]);

  return (
    <div
      aria-hidden
      className="absolute inset-0 overflow-hidden pointer-events-none bg-stone-950"
    >
      {imageUrls.map((imageUrl, index) => (
        <div
          key={imageUrl ?? "none"}
          className={classNames([
            "absolute inset-0 transition-opacity duration-600 ease-out",
            index > 0 && "starting:opacity-0",
          ])}
        >
          {imageUrl ? (
            <img
              src={imageUrl}
              alt=""
              className="w-full h-full object-cover scale-140 saturate-150 blur-[28px]"
            />
          ) : (
            <div className="w-full h-full bg-linear-to-tl from-stone-600 to-stone-700" />
          )}
        </div>
      ))}

      <div className="absolute inset-0 bg-black/45" />
    </div>
  );
}
