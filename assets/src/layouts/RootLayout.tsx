import { type ReactNode, useState } from "react";
import { Outlet } from "react-router";
import { Player } from "../components/Player";
import { useAuth } from "../hooks/useAuth";
import { usePlayer } from "../hooks/usePlayer";
import { type OnboardingStep, OnboardingView } from "../views/OnboardingView";

interface HydratedReact {
  onboarding: OnboardingStep;
}

declare var hydrateReact: HydratedReact;

let initialOnboardingStep = hydrateReact.onboarding;

interface Props {
  children?: ReactNode;
}

export function RootLayout({ children }: Props) {
  const { isLoggedIn, completeLogin } = useAuth();
  const { isVisible } = usePlayer();
  const [isOnboarding, setIsOnboarding] = useState<boolean>(
    initialOnboardingStep !== null,
  );

  const completeOnboarding = () => {
    initialOnboardingStep = null;
    setIsOnboarding(false);
  };

  const showOnboarding =
    isOnboarding &&
    (initialOnboardingStep === "user" ||
      (isLoggedIn && initialOnboardingStep === "settings"));

  if (showOnboarding) {
    return (
      <OnboardingView
        completeLogin={completeLogin}
        initialOnboardingStep={initialOnboardingStep}
        completeOnboarding={completeOnboarding}
      />
    );
  }

  return (
    <div className="flex flex-col h-full">
      {children ? children : <Outlet />}
      {isVisible && !isOnboarding && <Player />}
    </div>
  );
}
