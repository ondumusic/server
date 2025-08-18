import { useState } from "react";
import type { User } from "../types";
import { SettingsView } from "../views/onboarding/SettingsView";
import { SignupView } from "../views/onboarding/SignupView";

export type OnboardingStep = "user" | "settings" | null;

interface Props {
  initialOnboardingStep: OnboardingStep;
  completeLogin(_user: User, _sessionToken: string): void;
  completeOnboarding(): void;
}

export function OnboardingView({
  initialOnboardingStep,
  completeOnboarding,
  completeLogin,
}: Props) {
  const [onboardingStep, setOnboardingStep] = useState<OnboardingStep>(
    initialOnboardingStep,
  );

  return (
    <>
      {onboardingStep === "user" && (
        <SignupView
          completeLogin={completeLogin}
          setOnboardingStep={setOnboardingStep}
        />
      )}

      {onboardingStep === "settings" && (
        <SettingsView completeOnboarding={completeOnboarding} />
      )}
    </>
  );
}
