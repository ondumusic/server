import { resolve } from "node:path";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react-swc";
import { defineConfig, loadEnv } from "vite";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    publicDir: "public/",
    plugins: [tailwindcss(), react()],
    resolve: {
      alias: {
        "@/": resolve(__dirname, "./src"),
        "@test/factory": resolve(__dirname, "./test/factories"),
      },
    },
    build: {
      minify: mode === "dev" ? false : "esbuild",
      cssMinify: mode === "dev" ? false : "lightningcss",
      sourcemap: mode === "dev",
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
