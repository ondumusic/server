import { useEffect, useState } from "react";
import { router } from "../router";
import type { User } from "../types";
import { SignupView } from "../views/onboarding/SignupView";

export type OnboardingStep = "user" | "settings" | null;

interface Props {
  initialOnboardingStep: OnboardingStep;
  completeOnboarding(_user: User, _sessionToken: string): void;
}

export function OnboardingView({
  initialOnboardingStep,
  completeOnboarding,
}: Props) {
  const [onboardingStep, setOnboardingStep] = useState<OnboardingStep>(
    initialOnboardingStep,
  );

  // If we are onboarding there aren't really any useful other routes yet
  // so we can just make it
  useEffect(() => {
    router.navigate(`/`, { replace: true });
  }, []);

  return (
    <>
      {onboardingStep === "user" && (
        <SignupView
          completeOnboarding={completeOnboarding}
          setOnboardingStep={setOnboardingStep}
        />
      )}
    </>
  );
}
