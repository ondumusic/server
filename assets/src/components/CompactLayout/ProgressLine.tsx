import { useEffect, useState } from "react";
import { useAudioManager } from "../../hooks/useAudioManager";
import { classNames } from "../../utils/classNames";

export function ProgressLine({ className }: { className?: string }) {
  const { addTimeObserver } = useAudioManager();
  const [progressPercentage, setProgressPercentage] = useState<number>(0);

  useEffect(() => {
    return addTimeObserver(({ progressPercentage }) => {
      setProgressPercentage(progressPercentage);
    });
  }, [addTimeObserver]);

  return (
    <div className={classNames(["h-0.5 bg-white/20", className])}>
      <div
        className="h-full bg-white"
        style={{ width: `${progressPercentage}%` }}
      />
    </div>
  );
}
