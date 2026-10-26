// Plays an Ogg transcode "in progress" in the installed Chromium and reports when
// playback starts. The harness server simulates the transcode: ?live=N makes the
// file available at N bytes per second and ?tail=M serves the last M bytes right
// away, as the real server does for its padding. Run rangeserver.py first.
//   node web-live.mjs "long.ogg_opus_padded.opus?live=300000&tail=131072"
import { chromium } from "../../assets/node_modules/playwright/index.mjs";
const url = process.argv[2] || "long.ogg_opus_padded.opus?live=300000&tail=131072";
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || "/Applications/Chromium.app/Contents/MacOS/Chromium", headless: false, args: ["--autoplay-policy=no-user-gesture-required"] });
const page = await browser.newPage();
const reqs = [];
page.on("request", (r) => { if (r.url().includes(".opus")) reqs.push(r.headers()["range"] || "none"); });
await page.goto("http://127.0.0.1:8765/play.html");
const state = await page.evaluate((url) => new Promise((resolve) => {
  const a = document.getElementById("a");
  const out = { metadataAt: null, playingAt: null, duration: null, progressAt3s: null };
  const start = performance.now();
  a.addEventListener("loadedmetadata", () => { out.metadataAt = Math.round(performance.now() - start); out.duration = a.duration; });
  a.addEventListener("playing", () => { out.playingAt = Math.round(performance.now() - start); });
  a.src = url; a.load(); a.play().catch(() => {});
  setTimeout(() => { out.currentTime = a.currentTime; resolve(out); }, 12000);
}), url);
console.log(JSON.stringify(state), "requests:", reqs.join(" | "));
await browser.close();
