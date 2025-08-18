import { useState } from "react";
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
