import type { PropsWithChildren } from "react";
import { useTranslation } from "react-i18next";
import type { OnboardingStep } from "../types";
import { classNames } from "../utils/classNames";
import { CheckIcon } from "./icons/CheckIcon";

export function AuthLayout({
  title,
  subtitle,
  onboardingStep,
  children,
}: PropsWithChildren<{
  title: string;
  subtitle?: string;
  onboardingStep?: OnboardingStep;
}>) {
  const { t } = useTranslation();

  const steps = [
    {
      id: "user",
      label: t("onboarding.steps.account", { defaultValue: "Account" }),
    },
    {
      id: "settings",
      label: t("onboarding.steps.library", { defaultValue: "Library" }),
    },
  ];
  const currentStepIndex = steps.findIndex(
    (step) => step.id === onboardingStep,
  );

  return (
    <div className="h-full overflow-auto bg-page-bg text-page-fg">
      <main className="min-h-full flex items-center px-6 py-12 sm:px-12 lg:px-[12vw]">
        <div className="w-full max-w-sm">
          {onboardingStep && (
            <ol className="mb-8 flex items-center gap-5 text-sm font-medium">
              {steps.map((step, index) => {
                const stepCompleted = index < currentStepIndex;
                const isCurrentStep = index === currentStepIndex;
                const isHighlighted = stepCompleted || isCurrentStep;

                return (
                  <li
                    key={step.id}
                    className={classNames([
                      "flex items-center gap-2",
                      isCurrentStep ? "text-page-fg" : "text-page-fg-muted",
                    ])}
                  >
                    <span
                      className={classNames([
                        "grid place-items-center size-5 rounded-full text-[11px] font-semibold",
                        isHighlighted
                          ? "bg-accent-500 text-white"
                          : "bg-black/8 dark:bg-white/12",
                      ])}
                    >
                      {stepCompleted ? (
                        <CheckIcon
                          className="size-3"
                          strokeWidth={4}
                          title=""
                        />
                      ) : (
                        index + 1
                      )}
                    </span>
                    {step.label}
                  </li>
                );
              })}
            </ol>
          )}

          <h1 className="text-4xl font-bold tracking-tight">{title}</h1>
          {subtitle && <p className="mt-3 text-page-fg-muted">{subtitle}</p>}

          <div className="mt-10">{children}</div>
        </div>
      </main>
    </div>
  );
}
