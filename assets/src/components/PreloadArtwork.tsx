import { useEffect, useState } from "react";
import { Trans } from "react-i18next";
import { type PrewarmProgress, sync } from "../library/sync";
import { settings } from "../services/settings";
import { Button } from "./form/Button";
import { Loading } from "./Loading";

export function PreloadArtwork({ onDone }: { onDone: () => void }) {
  const [count, setCount] = useState<number>();
  const [preloading, setPreloading] = useState(false);
  const [progress, setProgress] = useState<PrewarmProgress>();

  // On mount we want to get the prewarmable count (albums and artists with
  // artwork available)
  useEffect(() => {
    sync.prewarmableCount().then(setCount);
  }, []);

  // Listen to the prewarm worker
  useEffect(() => sync.addPrewarmObserver(setProgress), []);

  // Report when done
  useEffect(() => {
    if (preloading && progress && progress.done >= progress.total) onDone();
  }, [preloading, progress, onDone]);

  // Start preloading
  const preload = async () => {
    settings.preloadArtwork.set(true);
    setPreloading(true);
    if (!(await sync.prewarmAll())) onDone();
  };

  // Skip preloading
  const skip = () => {
    settings.preloadArtwork.set(false);
    onDone();
  };

  if (preloading) {
    return (
      <Loading fullPage>
        <p className="text-center py-6 text-xs transition-opacity duration-500 starting:opacity-0">
          <Trans
            i18nKey="sync.preload.progressText"
            done={progress?.done ?? 0}
            total={progress?.total ?? count ?? 0}
          >
            Preloading artwork... {{ done: progress?.done ?? 0 }} of{" "}
            {{ total: progress?.total ?? count ?? 0 }}
          </Trans>
        </p>
        <div className="mx-auto max-w-xs">
          <Button type="button" link style="secondary" onClick={onDone}>
            <Trans i18nKey="sync.preload.background">
              Continue in background
            </Trans>
          </Button>
        </div>
      </Loading>
    );
  }

  return (
    <div className="w-full h-full content-center text-center transition-opacity duration-300 starting:opacity-0">
      <div className="mx-auto max-w-sm px-6">
        <h1 className="text-lg font-semibold">
          <Trans i18nKey="sync.preload.title">
            Do you want to preload artwork?
          </Trans>
        </h1>
        <p className="mt-1 text-sm text-page-fg-muted">
          <Trans i18nKey="sync.preload.question" count={count ?? 0}>
            This will start fetching and caching {{ count: count ?? 0 }} covers.
          </Trans>
        </p>
        <div className="mt-6 flex flex-col gap-2">
          <Button type="button" onClick={preload}>
            <Trans i18nKey="sync.preload.accept">Yes</Trans>
          </Button>
          <Button type="button" link onClick={skip}>
            <Trans i18nKey="sync.preload.skip">Skip</Trans>
          </Button>
        </div>
      </div>
    </div>
  );
}
