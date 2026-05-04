import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useState,
} from "react";

import {
  type AlertConfig,
  type CloseHandler,
  type CustomConfig,
  Dialog,
  type DialogResult,
  type PromptConfig,
} from "../components/Dialog";

interface DialogContextValue {
  showAlert(config: AlertConfig): Promise<DialogResult>;
  promptConfirm(config: PromptConfig): Promise<DialogResult>;
  showDialog(config: CustomConfig): Promise<DialogResult>;
}

type OpenDialog =
  | { type: "alert"; config: AlertConfig }
  | { type: "confirm"; config: PromptConfig }
  | { type: "custom"; config: CustomConfig };

interface DialogState {
  open: OpenDialog | null;
  resolve?: CloseHandler;
}

const DialogContext = createContext<DialogContextValue>({
  showAlert: (_config: AlertConfig) => new Promise((resolve) => resolve(false)),
  promptConfirm: (_config: PromptConfig) =>
    new Promise((resolve) => resolve(null)),
  showDialog: (_config: CustomConfig) =>
    new Promise((resolve) => resolve(null)),
});

export function useDialog() {
  return useContext(DialogContext);
}

export function DialogProvider({ children }: PropsWithChildren) {
  const [dialog, setDialog] = useState<DialogState>({
    open: null,
  });

  const showAlert = useCallback((config: AlertConfig) => {
    if (config.when && !config.when?.()) {
      return new Promise<DialogResult>((resolve) => resolve(true));
    }

    return new Promise<DialogResult>((resolve) => {
      setDialog({
        open: {
          type: "alert",
          config,
        },
        resolve,
      });
    });
  }, []);

  const promptConfirm = useCallback((config: PromptConfig) => {
    if (config.when && !config.when?.()) {
      return new Promise<DialogResult>((resolve) => resolve(true));
    }

    return new Promise<DialogResult>((resolve) => {
      setDialog({
        open: {
          type: "confirm",
          config,
        },
        resolve,
      });
    });
  }, []);

  const showDialog = useCallback((config: CustomConfig) => {
    return new Promise<DialogResult>((resolve) => {
      setDialog({
        open: {
          type: "custom",
          config,
        },
        resolve,
      });
    });
  }, []);

  const handleClose = (result: DialogResult) => {
    if (dialog.resolve) dialog.resolve(result);

    setDialog({
      open: null,
    });
  };

  return (
    <DialogContext.Provider
      value={{
        showAlert,
        showDialog,
        promptConfirm,
      }}
    >
      {children}
      {dialog.open && <Dialog {...dialog.open} onClose={handleClose} />}
    </DialogContext.Provider>
  );
}
