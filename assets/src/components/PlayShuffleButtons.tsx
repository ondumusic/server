import { Trans } from "react-i18next";
import { type PopulateInput, usePlayer } from "../hooks/usePlayer";
import { classNames } from "../utils/classNames";
import { PlayIcon } from "./icons/PlayIcon";
import { ShuffleIcon } from "./icons/ShuffleIcon";

export function PlayShuffleButtons({
  input,
  className,
}: {
  input: Omit<PopulateInput, "random">;
  className?: string;
}) {
  const { populateUpNext, userConfirmQueueReplace } = usePlayer();

  const handlePlay = async (random: boolean) => {
    if (!(await userConfirmQueueReplace())) return;
    populateUpNext({ ...input, random });
  };

  return (
    <div className={classNames(["flex gap-2", className])}>
      <button
        type="button"
        onClick={() => handlePlay(false)}
        className="flex items-center gap-1.5 rounded-md py-1 pl-2 pr-3 text-sm font-medium cursor-pointer bg-accent-500 hover:bg-accent-600 text-white"
      >
        <PlayIcon className="size-4" title="" />
        <Trans i18nKey="button.play">Play</Trans>
      </button>
      <button
        type="button"
        onClick={() => handlePlay(true)}
        className="flex items-center gap-1.5 rounded-md py-1 pl-2 pr-3 text-sm font-medium cursor-pointer bg-black/5 hover:bg-black/10 dark:bg-white/10 dark:hover:bg-white/15"
      >
        <ShuffleIcon className="size-4" title="" />
        <Trans i18nKey="button.shuffle">Shuffle</Trans>
      </button>
    </div>
  );
}
