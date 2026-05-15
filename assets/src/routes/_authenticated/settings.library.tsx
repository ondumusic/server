import { createFileRoute } from "@tanstack/react-router";
import { Trans } from "react-i18next";

export const Route = createFileRoute("/_authenticated/settings/library")({
  staticData: { view: "settings" as const },
  component: SettingsLayout,
});

function SettingsLayout() {
  return (
    <div className="h-full mx-4 lg:mx-8">
      <header className="mt-18 md:mt-4 lg:mt-8 @md:pb-4 mb-8 @md:border-b border-panel-fg-divider">
        <h1 className="font-semibold text-4xl lg:text-2xl line-clamp-1">
          <Trans i18nKey="settings.library.title">Library</Trans>
        </h1>
        <span className="text-sm text-panel-fg-muted">
          <Trans i18nKey="settings.library.subtitle">
            Change your music library settings
          </Trans>
        </span>
      </header>

      <div className="space-y-16">
        TODO: Add form for server settings, with save button
      </div>
    </div>
  );
}
