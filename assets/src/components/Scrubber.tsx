import { type ChangeEvent, useEffect, useRef, useState } from "react";
import { useAudioManager } from "../hooks/useAudioManager";
import { formatDuration } from "../utils/formatDuration";

export function Scrubber() {
  const { setIsPlaying, duration, scrubTo, addTimeObserver } =
    useAudioManager();
  const scrubTime = useRef<number>(0);
  const isScrubbing = useRef<boolean>(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [progressPercentage, setProgressPercentage] = useState(0);

  useEffect(() => {
    const unsubscribe = addTimeObserver(
      ({ currentTime, progressPercentage }) => {
        setCurrentTime(currentTime);
        setProgressPercentage(progressPercentage);
      },
    );

    return unsubscribe;
  }, [addTimeObserver]);

  const handleScrubStart = () => {
    isScrubbing.current = true;
    setIsPlaying(false);
  };

  const handleScrub = (event: ChangeEvent<HTMLInputElement>) => {
    if (!isScrubbing.current) return;
    const newCurrentTime = parseFloat(event.target.value);
    scrubTime.current = newCurrentTime;
    scrubTo(newCurrentTime);
  };

  const handleScrubEnd = () => {
    isScrubbing.current = false;
    if (!scrubTime.current) return;
    scrubTo(scrubTime.current, true);
  };

  return (
    <div className="group/timeline">
      <div className="relative h-1">
        <div className="absolute z-[10] bottom-0 left-0 right-0 bg-white/30 h-1 rounded-lg overflow-hidden">
          <div
            className="h-1 rounded-tr-lg rounded-br-lg bg-white"
            style={{ width: `${progressPercentage}%` }}
          ></div>
        </div>
        <input
          type="range"
          className="
              appearance-none bg-transparent z-[20] transition-colors duration-400
              absolute left-0 right-0 bottom-0
              [&::-webkit-slider-runnable-track]:bg-transparent
              [&::-webkit-slider-thumb]:appearance-none
              [&::-webkit-slider-thumb]:h-3
              [&::-webkit-slider-thumb]:w-3
              [&::-webkit-slider-thumb]:rounded-md
              [&::-webkit-slider-thumb]:transition-all
              [&::-webkit-slider-thumb]:shadow-none
              [&::-webkit-slider-thumb]:translate-y-[4px]
              [&::-webkit-slider-thumb]:translate-x-[-1px]
              [&::-webkit-slider-thumb]:bg-transparent
              group-hover/timeline:[&::-webkit-slider-thumb]:bg-white
              group-hover/timeline:[&::-webkit-slider-thumb]:shadow-xl
            "
          value={currentTime}
          min={0}
          max={duration}
          onChange={handleScrub}
          onMouseDown={handleScrubStart}
          onMouseUp={handleScrubEnd}
        />
      </div>

      <div className="flex justify-between items-end tabular-nums transition-colors duration-200 text-white/50 group-hover/timeline:text-white text-xs mt-2">
        <span>{formatDuration(currentTime)}</span>
        <span>{formatDuration(duration)}</span>
      </div>
    </div>
  );
}
