import { createFileRoute, useRouter } from "@tanstack/react-router";
import { useState } from "react";
import { Trans, useTranslation } from "react-i18next";
import { userApi } from "../../api";
import { Button } from "../../components/form/Button";
import { Input } from "../../components/form/Input";
import {
  SettingsActions,
  SettingsGroup,
  SettingsPage,
  SettingsRow,
} from "../../components/Settings";
import { useAuth } from "../../hooks/useAuth";
import { useDialog } from "../../hooks/useDialog";
import { type FormState, useForm } from "../../hooks/useForm";
import { useToast } from "../../hooks/useToast";
import { auth } from "../../services/auth";

export const Route = createFileRoute("/_authenticated/settings/account")({
  staticData: { view: "settings" as const },
  component: AccountSettings,
});

type PasswordFields = {
  password?: string;
  currentPassword?: string;
  passwordConfirmation?: string;
};

function AccountSettings() {
  const { t } = useTranslation();
  const { showToast } = useToast();
  const { promptConfirm } = useDialog();
  const { currentUser, logout } = useAuth();
  const router = useRouter();
  const [isChangingPassword, setIsChangingPassword] = useState(false);

  const onSubmit = async (prevState: FormState, formData: FormData) => {
    const newState: FormState = {
      ...prevState,
      errors: {},
    };

    const response = await userApi.updatePassword({
      password: formData.get("password") as string,
      passwordConfirmation: formData.get("passwordConfirmation") as string,
      currentPassword: formData.get("currentPassword") as string,
    });
    if (response.ok) {
      showToast({
        message: t("toast.updatedPassword", {
          defaultValue: "Updated your password",
        }),
      });
      newState.ok = true;
      auth.sessionToken = response.sessionToken;
      router.invalidate();
      form.resetAll();
      setIsChangingPassword(false);
    } else {
      newState.errors = response.fields;
      newState.ok = false;
    }

    return newState;
  };

  const form = useForm<PasswordFields>(
    "passwordForm",
    onSubmit,
    {},
    {
      horizontal: true,
    },
  );

  const handleLogout = async () => {
    const confirmed = await promptConfirm({
      message: t("promptLogout.message", {
        defaultValue: "Are you sure you want to logout?",
      }),
      confirmMessage: t("promptLogout.confirm", {
        defaultValue: "Logout",
      }),
      cancelMessage: t("promptLogout.cancel", {
        defaultValue: "Cancel",
      }),
    });
    if (!confirmed) return;
    logout();
  };

  const handleCancelPassword = () => {
    form.resetAll();
    setIsChangingPassword(false);
  };

  const logoutButton = (
    <button
      type="button"
      onClick={handleLogout}
      className="rounded-md px-3 py-1.5 text-sm font-medium cursor-pointer ring-1 ring-inset ring-black/10 dark:ring-white/15 hover:bg-black/5 dark:hover:bg-white/5"
    >
      <Trans i18nKey="settings.account.logout">Logout</Trans>
    </button>
  );

  return (
    <SettingsPage
      title={t("settings.account.title", { defaultValue: "Account" })}
      subtitle={t("settings.account.summary", {
        defaultValue: "Your account and password.",
      })}
    >
      <div className="flex items-center gap-4">
        <div className="grid place-items-center size-12 flex-shrink-0 rounded-full bg-accent-500 text-white text-lg font-semibold uppercase select-none">
          {currentUser?.username.charAt(0)}
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-semibold truncate">{currentUser?.username}</div>
          <div className="text-sm text-page-fg-muted truncate">
            {window.location.host}
          </div>
        </div>
        {logoutButton}
      </div>

      <form key={form.key} action={form.action}>
        <SettingsGroup
          title={t("settings.account.security", { defaultValue: "Security" })}
        >
          {!isChangingPassword && (
            <SettingsRow
              label={t("settings.account.password", {
                defaultValue: "Password",
              })}
            >
              <button
                type="button"
                onClick={() => setIsChangingPassword(true)}
                className="rounded-md px-3 py-1.5 text-sm font-medium cursor-pointer ring-1 ring-inset ring-black/10 dark:ring-white/15 hover:bg-black/5 dark:hover:bg-white/5"
              >
                <Trans i18nKey="settings.account.changePassword">
                  Change Password
                </Trans>
              </button>
            </SettingsRow>
          )}

          {isChangingPassword && (
            <Input<PasswordFields>
              form={form}
              type="password"
              field="password"
              label={t("passwordForm.field.password", {
                defaultValue: "New Password",
              })}
              autoFocus
              required
            />
          )}

          {isChangingPassword && (
            <Input<PasswordFields>
              form={form}
              type="password"
              field="passwordConfirmation"
              label={t("passwordForm.field.passwordConfirmation", {
                defaultValue: "Confirm Password",
              })}
              required
            />
          )}

          {isChangingPassword && (
            <Input<PasswordFields>
              form={form}
              type="password"
              field="currentPassword"
              label={t("passwordForm.field.currentPassword", {
                defaultValue: "Current Password",
              })}
              required
            />
          )}

          {isChangingPassword && (
            <SettingsActions
              secondaryAction={
                <button
                  type="button"
                  onClick={handleCancelPassword}
                  className="text-sm font-medium cursor-pointer text-page-fg-muted hover:text-page-fg"
                >
                  <Trans i18nKey="settings.account.cancelPassword">
                    Cancel
                  </Trans>
                </button>
              }
            >
              <Button
                disabled={!form.isDirty || form.isPending}
                type="submit"
                style="primary"
              >
                <Trans i18nKey="settings.password.save">Update Password</Trans>
              </Button>
            </SettingsActions>
          )}
        </SettingsGroup>
      </form>
    </SettingsPage>
  );
}
