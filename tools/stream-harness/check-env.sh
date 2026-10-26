#!/usr/bin/env bash
# Checks what this machine can run of the harness, and says what is missing.
# Exit code 1 when the asset generation itself cannot run.
set -u
ok=0; warn=0
pass() { echo "  ok    $1"; }
fail() { echo "  MISSING  $1"; ok=1; }
note() { echo "  warn  $1"; warn=1; }

echo "Required for generating assets:"
if command -v ffmpeg >/dev/null; then
  pass "ffmpeg $(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}')"
  ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libopus && pass "libopus encoder" || fail "ffmpeg without libopus (install an ffmpeg build with libopus)"
  ffmpeg -hide_banner -encoders 2>/dev/null | grep -q ' aac ' && pass "aac encoder" || fail "ffmpeg without the aac encoder"
else
  fail "ffmpeg (https://ffmpeg.org/download.html)"
fi
command -v ffprobe >/dev/null && pass "ffprobe" || fail "ffprobe"
if command -v python3 >/dev/null; then pass "python3 $(python3 --version 2>&1 | awk '{print $2}')"; else fail "python3 (the test server)"; fi

echo "AVPlayer probe (Apple platforms only):"
if [ "$(uname)" = "Darwin" ]; then
  if command -v swiftc >/dev/null; then pass "swiftc $(swiftc --version 2>/dev/null | head -1 | sed 's/.*Swift version \([0-9.]*\).*/\1/')"; else note "swiftc not found (install Xcode or the Command Line Tools)"; fi
  note "results apply to macOS $(sw_vers -productVersion 2>/dev/null) only, verify on the oldest iOS/macOS the apps support"
else
  note "not macOS: the AVPlayer probe cannot run here, use a Mac for that part"
fi

echo "Web probe:"
here="$(cd "$(dirname "$0")" && pwd)"
if [ -x "$here/../../assets/node_modules/.bin/playwright" ]; then
  pass "playwright (assets/node_modules)"
  if ls ~/Library/Caches/ms-playwright >/dev/null 2>&1 || ls ~/.cache/ms-playwright >/dev/null 2>&1; then
    pass "playwright browsers"
  else
    note "no playwright browsers installed: cd assets && pnpm exec playwright install chromium firefox webkit"
  fi
else
  note "playwright not installed: cd assets && pnpm install"
fi

echo "Android: no probe in this repo, see README.md"
[ $ok -eq 0 ] && echo "Asset generation can run." || echo "Asset generation cannot run until the missing tools are installed."
exit $ok
