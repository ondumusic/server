#!/usr/bin/env bash
# Runs the ffmpeg behaviours the server relies on inside the Docker runner image, so a
# difference between the Debian ffmpeg and a developer's own shows up here rather than
# in production. Needs podman or docker and the generated assets.
set -euo pipefail
cd "$(dirname "$0")"
[ -d assets ] || ./make-assets.sh
image=$(grep -E '^ARG DEBIAN_VERSION=' ../../Dockerfile | cut -d= -f2)
runner="docker.io/debian:$image"
engine=$(command -v podman || command -v docker)
work=$(mktemp -d)
cp assets/h1.flac assets/long.flac assets/long.ogg_opus_padded.opus "$work/"
cat > "$work/run.sh" <<'INNER'
set -e
apt-get update -qq >/dev/null && apt-get install -y -qq --no-install-recommends ffmpeg >/dev/null 2>&1
cd /work
echo "ffmpeg: $(ffmpeg -version 2>/dev/null | head -1)"
echo "encoders: $(ffmpeg -hide_banner -encoders 2>/dev/null | grep -E '^ A.* (aac|libopus) ' | awk '{print $2}' | tr '\n' ' ') (both needed)"
ffmpeg -nostdin -v error -y -i h1.flac -c:a aac -b:a 256k -f mp4 -ar 44100 h1.m4a
echo "aac m4a, ffprobe start_pts,duration_ts: $(ffprobe -v error -show_entries stream=start_pts,duration_ts -of csv=p=0 h1.m4a) (0,220500: edit list written and applied, Trim relies on it)"
echo "aac m4a decoded samples: $(ffmpeg -nostdin -v error -i h1.m4a -f s16le -ac 1 pipe:1 | wc -c | awk '{print $1/2}') (221184: ffmpeg keeps the end padding, Trim cuts it)"
ffmpeg -nostdin -v error -y -i long.flac -c:a libopus -b:a 192k -vbr off -f ogg -ar 48000 -vn -ac 2 -map_metadata -1 long.opus
echo "ogg 192k CBR, 180s: $(stat -c%s long.opus) bytes (4343505 or 4343506: packet sizes are exact, the size prediction holds)"
echo "ogg decoded samples: $(ffmpeg -nostdin -v error -i long.opus -f s16le -ac 1 -ar 48000 pipe:1 | wc -c | awk '{print $1/2}') (8640000)"
echo "page-padded ogg duration: $(ffprobe -v error -show_entries format=duration -of csv=p=0 long.ogg_opus_padded.opus) (180.0065: empty pages keep the duration)"
INNER
"$engine" run --rm -v "$work:/work" "$runner" bash /work/run.sh 2>&1 | grep -v '^debconf\|^$'
rm -rf "$work"
