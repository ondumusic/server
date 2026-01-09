import { type PropsWithChildren, useState } from "react";
import { Outlet, useLocation, useNavigate } from "react-router";
import { Panel } from "../components/Panel";
import { Player } from "../components/Player";
import { useAuth } from "../hooks/useAuth";
import { usePhoenixSocket } from "../hooks/usePhoenixSocket";
import { useQueue } from "../hooks/useQueue";
import { FirstLoadView } from "../views/FirstLoadView";
import { type OnboardingStep, OnboardingView } from "../views/OnboardingView";

interface HydratedReact {
  onboarding: OnboardingStep;
}

declare var hydrateReact: HydratedReact;

let initialOnboardingStep = hydrateReact.onboarding;

export function RootLayout({ children }: PropsWithChildren) {
  const { isLoggedIn, completeLogin } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const { queue } = useQueue();

  const { waitForUpdate } = usePhoenixSocket();
  const [isWaitingForData, setIsWaitingForData] = useState<boolean>(false);
  const [isPanelOpen, setIsPanelOpen] = useState(
    location.pathname !== "/" || queue.length === 0,
  );

  const [isOnboarding, setIsOnboarding] = useState<boolean>(
    initialOnboardingStep !== null,
  );

  const completeOnboarding = () => {
    setIsWaitingForData(true);

    waitForUpdate(() => {
      initialOnboardingStep = null;
      setIsOnboarding(false);
      navigate("/");
    });
  };

  if (!isLoggedIn) {
    return <>{children ? children : <Outlet />}</>;
  }

  if (isWaitingForData) {
    return <FirstLoadView />;
  }

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
    <div className="relative h-full">
      <div
        className={
          "absolute lg:w-1/3 xl:w-1/4 h-full left-0 overflow-hidden lg:p-6 xl:p-8 " +
          "flex justify-center items-center flex-col " +
          "transition-all duration-400 ease-in-out " +
          (isPanelOpen
            ? " translate-x-0"
            : " lg:translate-x-full xl:translate-x-[150%]")
        }
      >
        {!isOnboarding && <Player />}
        <button
          type="button"
          className="mt-4"
          onClick={() => setIsPanelOpen(!isPanelOpen)}
        >
          Toggle Panel
        </button>
      </div>

      <div
        className={
          "absolute lg:left-1/3 lg:w-2/3 xl:left-1/4 xl:w-3/4 h-full lg:p-4 xl:p-6 lg:pl-0 xl:pl-0 " +
          "flex justify-center items-center flex-col " +
          "transition-all duration-400 ease-in-out " +
          (isPanelOpen
            ? " translate-x-0 opacity-100 scale-100"
            : " translate-x-full opacity-0 scale-90")
        }
      >
        <Panel main>{children ? children : <Outlet />}</Panel>
      </div>
    </div>
  );
}
