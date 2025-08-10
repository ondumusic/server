import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import en_US from "../locales/en_US/translation.json";

const resources = {
  en_US: {
    translation: en_US,
  },
};

i18n.use(initReactI18next).init({
  resources,
  lng: "en_US",
  interpolation: {
    escapeValue: false,
  },
});

export default i18n;
