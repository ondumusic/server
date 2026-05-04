import {
  type PropsWithChildren,
  type ReactNode,
  useEffect,
  useRef,
} from "react";
import { Button } from "../components/form/Button";
import { classNames } from "../utils/classNames";

export type DialogType = "alert" | "confirm" | "custom";
export type DialogResult = boolean | null;
export type CloseHandler = (result: DialogResult) => void;

interface DialogConfig {
  title?: string;
  message: string;
  danger?: boolean;
  confirmMessage?: string;
  when?: () => boolean;
}

export type AlertConfig = DialogConfig;

export type PromptConfig = DialogConfig & {
  cancelMessage?: string;
};

export type CustomConfig = {
  renderDialog: (dismiss: CloseHandler) => ReactNode;
};

type Props = PropsWithChildren<
  | {
      type: "alert";
      config: AlertConfig;
      onClose: CloseHandler;
    }
  | {
      type: "confirm";
      config: PromptConfig;
      onClose: CloseHandler;
    }
  | {
      type: "custom";
      config: CustomConfig;
      onClose: CloseHandler;
    }
>;

export function Dialog({ type, config, onClose }: Props) {
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
        "rounded-md shadow-2xl bg-dialog-bg text-dialog-fg",
        "max-w-md dialog-modal",
      ])}
    >
      {type === "custom" ? (
        <div>{config.renderDialog(onClose)}</div>
      ) : (
        <div className="p-6 space-y-8">
          {config.title && (
            <h4 className="text-xl font-semibold pb-1 border-b border-stone-300">
              {config.title}
            </h4>
          )}

          <p>{config.message}</p>

          <div className="flex flex-row-reverse gap-2 justify-start items-center">
            <div>
              <Button
                type="button"
                style={config.danger === true ? "danger" : "primary"}
                onClick={handleConfirm}
              >
                {config.confirmMessage}
              </Button>
            </div>
            {type === "confirm" && (config as PromptConfig).cancelMessage && (
              <div>
                <Button
                  type="button"
                  style="secondary"
                  link
                  onClick={handleCancel}
                >
                  {(config as PromptConfig).cancelMessage}
                </Button>
              </div>
            )}
          </div>
        </div>
      )}
    </dialog>
  );
}
