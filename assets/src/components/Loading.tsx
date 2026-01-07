import type { ReactNode } from "react";
import { Trans } from "react-i18next";

interface Props {
  children?: ReactNode;
}

export function Loading({ children }: Props) {
  return (
    <div className="w-full h-full content-center text-accent-500/50">
      <svg width="60" height="20" viewBox="0 0 120 30" className="mx-auto">
        <title>
          <Trans i18nKey="loading.text">Loading</Trans>
        </title>
        <circle cx="30" cy="15" r="10" fill="currentColor">
          <animate
            attributeName="cy"
            from="15"
            to="15"
            dur="0.6s"
            begin="0s"
            repeatCount="indefinite"
            values="15;5;15"
            keyTimes="0;0.5;1"
          ></animate>
        </circle>
        <circle cx="60" cy="15" r="10" fill="currentColor">
          <animate
            attributeName="cy"
            from="15"
            to="15"
            dur="0.6s"
            begin="0.2s"
            repeatCount="indefinite"
            values="15;5;15"
            keyTimes="0;0.5;1"
          ></animate>
        </circle>
        <circle cx="90" cy="15" r="10" fill="currentColor">
          <animate
            attributeName="cy"
            from="15"
            to="15"
            dur="0.6s"
            begin="0.4s"
            repeatCount="indefinite"
            values="15;5;15"
            keyTimes="0;0.5;1"
          ></animate>
        </circle>
      </svg>
      {children}
    </div>
  );
}
