import { defineConfig } from "i18next-cli";

export default defineConfig({
  locales: ["en-US"],
  extract: {
    input: "src/**/*.{js,jsx,ts,tsx}",
    output: "locales/{{language}}/{{namespace}}.json",
    defaultNS: "translation",
    functions: ["t", "*.t"],
    transComponents: ["Trans"],
  },
  types: {
    input: ["locales/{{language}}/{{namespace}}.json"],
    output: "src/types/i18next.d.ts",
  },
});
