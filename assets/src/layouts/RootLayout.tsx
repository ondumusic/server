import { type ReactNode, useState } from "react";
import { Outlet, useNavigate } from "react-router";
import { Loading } from "../components/Loading";
import { Player } from "../components/Player";
import { useAuth } from "../hooks/useAuth";
import { usePhoenixSocket } from "../hooks/usePhoenixSocket";
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
  const navigate = useNavigate();
  const { waitForUpdate } = usePhoenixSocket();
  const [isOnboarding, setIsOnboarding] = useState<boolean>(
    initialOnboardingStep !== null,
  );
  const [isWaitingForData, setIsWaitingForData] = useState<boolean>(false);

  const completeOnboarding = () => {
    setIsWaitingForData(true);

    waitForUpdate(() => {
      initialOnboardingStep = null;
      setIsOnboarding(false);
      navigate("/");
    });
  };

  if (isWaitingForData) return <Loading />;

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
