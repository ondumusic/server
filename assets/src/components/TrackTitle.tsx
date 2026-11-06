import { useAudioManager } from "../hooks/useAudioManager";
import { classNames } from "../utils/classNames";
import { SpinnerIcon } from "./icons/SpinnerIcon";
import { Marquee } from "./Marquee";

export function TrackTitle({
  text,
  className,
}: {
  text: string;
  className?: string;
}) {
  const { isBuffering } = useAudioManager();

  return (
    <div
      className={classNames(["flex items-center gap-1.5 min-w-0", className])}
    >
      {isBuffering && (
        <SpinnerIcon
          className="size-[1em] flex-shrink-0 animate-spin"
          strokeWidth={3}
          title=""
        />
      )}
      <Marquee className="min-w-0 flex-1" text={text} />
    </div>
  );
}
