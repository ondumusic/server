import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react-swc";
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    publicDir: "public/",
    plugins: [tailwindcss(), react()],
    build: {
      outDir: "../priv/static",
      emptyOutDir: true,
      copyPublicDir: true,
      rollupOptions: {
        input: "src/app.tsx",
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
