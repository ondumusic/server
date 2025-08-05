import "./app.css";

import { StrictMode, Suspense, useEffect } from "react";
import { createRoot } from "react-dom/client";

const appRoot = document.getElementById("App");
if (appRoot) {
  const root = createRoot(appRoot);

  root.render(
    <StrictMode>
      <Suspense>
        <div class="w-screen h-screen flex items-center justify-center">
          <p class="max-w-md mx-4">
            Hello <span class="font-bold">React</span>!
          </p>
        </div>
      </Suspense>
    </StrictMode>,
  );
}
