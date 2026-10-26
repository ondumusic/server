#!/usr/bin/env bash
# Runs the AVPlayer probe over the generated assets: seek/duration per format,
# served as a complete file with ranges, as a chunked response without a
# length (a live transcode without a known size), and the gapless frame count
# for two queued halves. Prints one block per case.
set -euo pipefail
cd "$(dirname "$0")"
[ "$(uname)" = "Darwin" ] || { echo "AVPlayer probe only runs on macOS"; exit 1; }
[ -d assets ] || ./make-assets.sh
[ -x avprobe ] && [ avprobe -nt avprobe.swift ] || swiftc -O -Xfrontend -disable-availability-checking avprobe.swift -o avprobe -framework AVFoundation -framework MediaToolbox
port=${PORT:-8765}
python3 -I rangeserver.py "$port" > server.log 2>&1 &
server=$!; trap 'kill $server' EXIT; sleep 1
base=http://127.0.0.1:$port
formats="ogg_opus.opus ogg_opus_padded.opus aac.m4a adts.aac webm_opus.webm fmp4.m4a opus_mp4.mp4"

echo "=== complete file, ranged, throttled to ~10x realtime"
for f in $formats; do ./avprobe probe "$base/long.$f?kbps=2000"; done
echo "=== chunked, no content-length"
for f in $formats; do ./avprobe probe "$base/long.$f?chunked=1&kbps=2000"; done
echo "=== gapless: signalFrames must equal expected"
for f in $formats; do ./avprobe gapless "$base/h1.$f" "$base/h2.$f"; done
