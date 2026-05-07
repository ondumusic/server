import { Link } from "@tanstack/react-router";
import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import i18next from "../i18next";
import { classNames } from "../utils/classNames";

export interface ToastMessage {
  message: string;
  link?: string;
  linkTitle?: string;
}

interface ToastContextValue {
  clearToast(): void;
  showToast(message: ToastMessage): void;
}

const ToastContext = createContext<ToastContextValue>({
  clearToast: () => null,
  showToast: (_message: ToastMessage) => null,
});

export function useToast() {
  return useContext(ToastContext);
}

const Toast = ({
  message,
  show,
  dismiss,
  onMouseEnter,
  onMouseLeave,
}: {
  message: ToastMessage | null;
  show: boolean;
  dismiss: () => void;
  onMouseEnter: () => void;
  onMouseLeave: () => void;
}) => {
  const [toast, setToast] = useState<ToastMessage | null>(message);
  useEffect(() => {
    if (message) setToast(message);
  }, [message]);

  return (
    <div className="absolute left-1/2 max-w-1/2 -translate-x-1/2 bottom-8">
      <div
        className={classNames([
          "flex gap-2 bg-toast-bg text-toast-fg px-4 py-2 text-center text-sm rounded-md shadow-md",
          "transition-translate-y transition-all duration-250",
          "[transition-timing-function:cubic-bezier(0.34,1.56,0.64,1)]",
          show
            ? "translate-y-0 opacity-100 scale-100"
            : "translate-y-8 opacity-0 scale-95 pointer-events-none",
        ])}
        role="status"
        aria-live="polite"
        onMouseEnter={onMouseEnter}
        onMouseLeave={onMouseLeave}
        onFocus={onMouseEnter}
        onBlur={onMouseLeave}
      >
        <span>{toast?.message}</span>

        {toast?.link && (
          <Link
            to={toast?.link}
            onClick={dismiss}
            className="underline hover:no-underline"
          >
            {toast.linkTitle ??
              i18next.t("toast.defaultLinkTitle", {
                defaultValue: "View",
              })}
          </Link>
        )}
      </div>
    </div>
  );
};

export function ToastProvider({ children }: PropsWithChildren) {
  const [toast, setToast] = useState<ToastMessage | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout>>(null);
  const remainingRef = useRef(0);
  const startedAtRef = useRef(0);

  const DURATION = 3000;

  const clearTimer = useCallback(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const startTimer = useCallback(
    (ms: number) => {
      clearTimer();
      startedAtRef.current = Date.now();
      remainingRef.current = ms;
      timerRef.current = setTimeout(() => {
        setToast(null);
        timerRef.current = null;
      }, ms);
    },
    [clearTimer],
  );

  const showToast = useCallback(
    (message: ToastMessage) => {
      setToast(message);
      startTimer(DURATION);
    },
    [startTimer],
  );

  const clearToast = useCallback(() => {
    clearTimer();
    remainingRef.current = 0;
    setToast(null);
  }, [clearTimer]);

  const pauseTimer = useCallback(() => {
    if (!timerRef.current) return;
    clearTimer();
    const elapsed = Date.now() - startedAtRef.current;
    remainingRef.current = Math.max(0, remainingRef.current - elapsed);
  }, [clearTimer]);

  const resumeTimer = useCallback(() => {
    if (remainingRef.current > 0 && toast) {
      startTimer(remainingRef.current);
    }
  }, [toast, startTimer]);

  useEffect(() => () => clearTimer(), [clearTimer]);

  return (
    <ToastContext.Provider
      value={{
        showToast,
        clearToast,
      }}
    >
      {children}
      <Toast
        message={toast}
        show={toast !== null}
        dismiss={clearToast}
        onMouseEnter={pauseTimer}
        onMouseLeave={resumeTimer}
      />
    </ToastContext.Provider>
  );
}
