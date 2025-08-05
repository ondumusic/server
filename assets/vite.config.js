import { loadEnv, defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    publicDir: "public/",
    plugins: [tailwindcss()],
    build: {
      outDir: "../priv/static",
      emptyOutDir: true,
      copyPublicDir: true,
      target: ["es2022"],
      rollupOptions: {
        input: "src/app.js",
        output: {
          assetFileNames: "assets/[name][extname]",
          chunkFileNames: "[name].js",
          entryFileNames: "assets/[name].js",
        },
      },
      commonjsOptions: {
        exclude: [],
        include: [],
      },
    },
    define: {
      __APP_ENV__: env.APP_ENV,
    },
  };
});
