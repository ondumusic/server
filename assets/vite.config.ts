import { resolve } from "node:path";
import tailwindcss from "@tailwindcss/vite";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react from "@vitejs/plugin-react-swc";
// import { defineConfig, loadEnv } from "vite";
import { defineConfig } from "vite";

export default defineConfig(({ mode }) => {
  // const env = loadEnv(mode, process.cwd(), "");

  return {
    publicDir: "public/",
    plugins: [
      tanstackRouter({
        target: "react",
        autoCodeSplitting: false,
        routesDirectory: resolve(__dirname, "./src/routes"),
        generatedRouteTree: resolve(__dirname, "./src/routeTree.gen.ts"),
      }),
      tailwindcss(),
      react(),
    ],
    resolve: {
      alias: {
        "@/": resolve(__dirname, "./src"),
        "@test/factory": resolve(__dirname, "./test/factories"),
      },
    },
    build: {
      minify: mode === "dev" ? false : "terser",
      cssMinify: mode === "dev" ? false : "lightningcss",
      sourcemap: mode === "dev",
      outDir: "../priv/static",
      emptyOutDir: true,
      copyPublicDir: true,
      rollupOptions: {
        input: {
          app: "src/app.tsx",
          sw: "src/sw.ts",
        },
        output: {
          assetFileNames: "assets/[name][extname]",
          chunkFileNames: "assets/[name].js",
          entryFileNames: (chunk) =>
            chunk.name === "sw" ? "[name].js" : "assets/[name].js",
        },
        // 1000 is default, CI was being difficult and wanted 1. I don't
        // remember exactly where the issue was but I believe with docker buildx
        maxParallelFileOps: "CI" in process.env ? 1 : 1000,
      },
    },
    test: {
      globals: true,
    },
  };
});
