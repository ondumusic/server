// Web probe: which formats each browser engine plays from an <audio> element,
// whether it reports a duration and can seek, for complete and chunked
// delivery. Needs playwright browsers: cd assets && pnpm exec playwright install
// Usage: node web-probe.mjs [port]   (run rangeserver.py on that port first)
import { chromium, firefox, webkit } from "../../assets/node_modules/playwright/index.mjs";

const port = process.argv[2] || "8765";
const base = `http://127.0.0.1:${port}`;
const formats = ["ogg_opus.opus", "ogg_opus_padded.opus", "aac.m4a", "adts.aac", "webm_opus.webm", "fmp4.m4a", "opus_mp4.mp4"];

async function probe(page, url) {
  return page.evaluate(async (url) => {
    const a = new Audio();
    a.preload = "auto";
    const result = { ready: false, duration: null, seeked: false, error: null };
    const done = new Promise((resolve) => {
      a.addEventListener("loadedmetadata", () => { result.ready = true; result.duration = a.duration; });
      a.addEventListener("canplay", async () => {
        a.muted = true;
        try { await a.play(); } catch (e) { result.error = "play: " + e.name; }
        a.currentTime = Number.isFinite(a.duration) ? a.duration * 0.6 : 3;
        a.addEventListener("seeked", () => { result.seeked = true; result.seekedTo = a.currentTime; resolve(); }, { once: true });
        setTimeout(resolve, 4000);
      }, { once: true });
      a.addEventListener("error", () => { result.error = "media error " + (a.error && a.error.code); resolve(); });
      setTimeout(resolve, 10000);
    });
    a.src = url;
    a.load();
    await done;
    a.pause();
    return result;
  }, url);
}

for (const [name, engine] of [["chromium", chromium], ["firefox", firefox], ["webkit", webkit]]) {
  let browser;
  try { browser = await engine.launch(); } catch (e) { console.log(`${name}: not installed (${e.message.split("\n")[0]})`); continue; }
  const page = await browser.newPage();
  for (const mode of ["", "?chunked=1"]) {
    for (const f of formats) {
      const r = await probe(page, `${base}/long.${f}${mode}`);
      console.log(`${name} ${mode || "ranged"} long.${f}: ready=${r.ready} duration=${r.duration && r.duration.toFixed(2)} seeked=${r.seeked}${r.seekedTo ? " to " + r.seekedTo.toFixed(2) : ""} ${r.error || ""}`);
    }
  }
  await browser.close();
}
