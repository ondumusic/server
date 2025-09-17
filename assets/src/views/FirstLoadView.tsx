import { Trans } from "react-i18next";
import { Loading } from "../components/Loading";

export function FirstLoadView() {
  return (
    <Loading>
      <div className="text-stone-600 text-center text-sm mt-4">
        <Trans i18nKey="onboarding.firstLoadWait">Finding your music...</Trans>
      </div>
    </Loading>
  );
}
