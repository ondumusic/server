import {
  createContext,
  type PropsWithChildren,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import { Button } from "../components/form/Button";
import { classNames } from "../utils/classNames";

type DialogType = "alert" | "confirm";
type DialogResult = boolean | null;

interface DialogConfig {
  title?: string;
  message: string;
  confirmMessage?: string;
  when?: () => boolean;
}

type AlertConfig = DialogConfig;

type PromptConfig = DialogConfig & {
  cancelMessage?: string;
};

interface DialogContextValue {
  showAlert(config: AlertConfig): Promise<DialogResult>;
  promptConfirm(config: PromptConfig): Promise<DialogResult>;
}

interface DialogState {
  type: DialogType;
  config: AlertConfig | PromptConfig | null;
  isOpen: boolean;
  resolve?: (value: DialogResult) => void;
}

const DialogContext = createContext<DialogContextValue>({
  showAlert: (_config: AlertConfig) => new Promise((resolve) => resolve(false)),
  promptConfirm: (_config: PromptConfig) =>
    new Promise((resolve) => resolve(null)),
});

export function useDialog() {
  return useContext(DialogContext);
}

function Dialog({
  type,
  config,
  onClose,
}: PropsWithChildren<{
  type: DialogType;
  config: AlertConfig | PromptConfig;
  onClose: (result: DialogResult) => void;
}>) {
  const dialogRef = useRef<HTMLDialogElement>(null);

  const handleCancel = () => {
    onClose(false);
  };

  const handleConfirm = () => {
    onClose(true);
  };

  // Show the dialog modal immediately
  useEffect(() => {
    const dialogEl = dialogRef.current;
    if (!dialogEl) return;
    dialogEl.showModal();

    const handleDismiss = () => {
      onClose(type === "alert" ? false : null);
    };

    dialogEl.addEventListener("cancel", handleDismiss);
    return () => {
      dialogEl.removeEventListener("cancel", handleDismiss);
    };
  }, [onClose, type]);

  return (
    <dialog
      ref={dialogRef}
      className={classNames([
        "self-center justify-self-center outline-none",
        "rounded-md shadow-2xl bg-panel-bg text-panel-fg",
        "max-w-md",
      ])}
    >
      <div className="p-6 space-y-8">
        {config.title && (
          <h4 className="text-xl font-semibold pb-1 border-b border-stone-300">
            {config.title}
          </h4>
        )}

        <p>{config.message}</p>

        <div className="flex flex-row-reverse gap-2 justify-start items-center">
          <div>
            <Button type="button" onClick={handleConfirm}>
              {config.confirmMessage}
            </Button>
          </div>
          {type === "confirm" && (config as PromptConfig).cancelMessage && (
            <div>
              <Button type="button" link onClick={handleCancel}>
                {(config as PromptConfig).cancelMessage}
              </Button>
            </div>
          )}
        </div>
      </div>
    </dialog>
  );
}

export function DialogProvider({ children }: PropsWithChildren) {
  const [dialog, setDialog] = useState<DialogState>({
    type: "alert",
    config: null,
    isOpen: false,
  });

  const showAlert = (config: AlertConfig) => {
    if (!config.when?.()) {
      return new Promise<DialogResult>((resolve) => resolve(true));
    }

    return new Promise<DialogResult>((resolve) => {
      setDialog({
        type: "alert",
        isOpen: true,
        config,
        resolve,
      });
    });
  };

  const promptConfirm = (config: PromptConfig) => {
    if (!config.when?.()) {
      return new Promise<DialogResult>((resolve) => resolve(true));
    }

    return new Promise<DialogResult>((resolve) => {
      setDialog({
        type: "confirm",
        isOpen: true,
        config,
        resolve,
      });
    });
  };

  const handleClose = (result: DialogResult) => {
    if (dialog.resolve) dialog.resolve(result);

    setDialog({
      type: "alert",
      config: null,
      isOpen: false,
    });
  };

  return (
    <DialogContext.Provider
      value={{
        showAlert,
        promptConfirm,
      }}
    >
      {children}
      {dialog.isOpen && dialog.config && (
        <Dialog
          type={dialog.type}
          config={dialog.config}
          onClose={handleClose}
        />
      )}
    </DialogContext.Provider>
  );
}
