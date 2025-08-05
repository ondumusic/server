import { loadEnv, defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    publicDir: "public/",
    plugins: [
      tailwindcss(),
      react()
    ],
    build: {
      outDir: "../priv/static",
      emptyOutDir: true,
      copyPublicDir: true,
      rollupOptions: {
        input: "src/app.jsx",
        output: {
          assetFileNames: "assets/[name][extname]",
          chunkFileNames: "[name].js",
          entryFileNames: "assets/[name].js",
        },
      },
    },
    define: {
      __APP_ENV__: env.APP_ENV,
    },
  };
});
