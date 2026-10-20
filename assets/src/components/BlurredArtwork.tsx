import { useEffect, useState } from "react";
import { useQueue } from "../hooks/useQueue";
import { useAlbum } from "../library";
import { artworkUrl } from "../utils/artwork";

// Same as the iOS and macOS app we'll use a blurred version of the album
// artwork as the background for things like the mini player.
export function BlurredArtwork() {
  const { currentTrack } = useQueue();
  const { data: album } = useAlbum(currentTrack?.albumId);
  const url = artworkUrl(album);
  const [imageUrls, setImageUrls] = useState<(string | undefined)[]>([url]);

  // Only keep the previous image to fade from
  useEffect(() => {
    setImageUrls((imageUrls) => {
      if (imageUrls.at(-1) === url) return imageUrls;
      return [...imageUrls.slice(-1), url];
    });
  }, [url]);

  return (
    <div
      aria-hidden
      className="absolute inset-0 overflow-hidden pointer-events-none bg-mist-950"
    >
      {imageUrls.map((imageUrl) => (
        <div
          key={imageUrl ?? "none"}
          className="absolute inset-0 transition-opacity duration-600 ease-out starting:opacity-0"
        >
          {imageUrl ? (
            <img
              src={imageUrl}
              alt=""
              className="w-full h-full object-cover scale-140 saturate-150 blur-[28px]"
            />
          ) : (
            <div className="w-full h-full bg-linear-to-tl from-mist-600 to-mist-700" />
          )}
        </div>
      ))}

      <div className="absolute inset-0 bg-black/45" />
    </div>
  );
}
