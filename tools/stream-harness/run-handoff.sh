#!/usr/bin/env bash
# Records what the Mac actually plays while AVQueuePlayer hands over between two halves
# of one continuous tone, then looks for a dip or a phase jump at the join. The only
# measurement that sees a gap the player inserts in time; the tap in avprobe cannot.
#
# Needs the Screen Recording permission for the terminal running this (System Settings
# > Privacy & Security > Screen & System Audio Recording), and the output not muted:
# the capture is taken before the volume control, but a muted device plays nothing.
set -euo pipefail
cd "$(dirname "$0")"
[ "$(uname)" = "Darwin" ] || { echo "macOS only"; exit 1; }
# Anything else playing ends up in the recording and drowns the tone.
quiet() { ./syscapture 2 captures/_quiet.wav >/dev/null 2>&1 && python3 -I -c "
import wave,struct,sys; w=wave.open('captures/_quiet.wav'); x=struct.unpack(f'<{w.getnframes()}h', w.readframes(w.getnframes()))
sys.exit(1 if x and max(abs(v) for v in x) > 64 else 0)"; }
mkdir -p captures
[ -d assets ] || ./make-assets.sh
for t in avprobe syscapture; do
  [ -x $t ] && [ $t -nt $t.swift ] && continue
  case $t in
    avprobe) swiftc -O -Xfrontend -disable-availability-checking avprobe.swift -o avprobe -framework AVFoundation -framework MediaToolbox ;;
    syscapture) swiftc -O -Xfrontend -disable-availability-checking syscapture.swift -o syscapture -framework ScreenCaptureKit -framework AVFoundation ;;
  esac
done
quiet || { echo "something is playing: pause it and run again"; exit 1; }
port=${PORT:-8765}
python3 -I rangeserver.py "$port" > server.log 2>&1 &
server=$!; trap 'kill $server' EXIT; sleep 1
base=http://127.0.0.1:$port
mkdir -p captures
# One case per line: name, environment for the probe, the two halves. The first case
# keeps the audio tap on, which is how the frame counts are measured; it turned out to
# cost a handoff of about 440 ms by itself, so every other case runs without it. The
# local cases play files, as downloads do, without the stall wait the app also skips
# for local files. Mixed pairs are what a real queue can hold: an older cached ADTS
# or downloaded AAC track next to an Ogg stream.
base_http=$base; base_file="file://$PWD/assets"
cases=(
  "tap_aac|AVPROBE_TAP=1|$base_http/h1.aac.m4a|$base_http/h2.aac.m4a"
  "http_aac|AVPROBE_TAP=0|$base_http/h1.aac.m4a|$base_http/h2.aac.m4a"
  "http_ogg|AVPROBE_TAP=0|$base_http/h1.ogg_opus.opus|$base_http/h2.ogg_opus.opus"
  "http_ogg_padded|AVPROBE_TAP=0|$base_http/h1.ogg_opus_padded.opus|$base_http/h2.ogg_opus_padded.opus"
  "http_ogg_zeros|AVPROBE_TAP=0|$base_http/h1.ogg_opus_zeros.opus|$base_http/h2.ogg_opus_zeros.opus"
  "http_adts|AVPROBE_TAP=0|$base_http/h1.adts.aac|$base_http/h2.adts.aac"
  "http_aac_to_ogg|AVPROBE_TAP=0|$base_http/h1.aac.m4a|$base_http/h2.ogg_opus.opus"
  "http_ogg_to_aac|AVPROBE_TAP=0|$base_http/h1.ogg_opus.opus|$base_http/h2.aac.m4a"
  "local_aac|AVPROBE_TAP=0 AVPROBE_NOSTALL=1|$base_file/h1.aac.m4a|$base_file/h2.aac.m4a"
  "local_ogg|AVPROBE_TAP=0 AVPROBE_NOSTALL=1|$base_file/h1.ogg_opus.opus|$base_file/h2.ogg_opus.opus"
  "local_ogg_padded|AVPROBE_TAP=0 AVPROBE_NOSTALL=1|$base_file/h1.ogg_opus_padded.opus|$base_file/h2.ogg_opus_padded.opus"
)
for case in "${cases[@]}"; do
  IFS='|' read -r name envs a b <<< "$case"
  echo "=== $name"
  ./syscapture 12 "captures/$name.wav" > "captures/$name.log" 2>&1 &
  capture=$!; sleep 1.5
  env $envs AVPROBE_VOLUME=${AVPROBE_VOLUME:-0.3} ./avprobe gapless "$a" "$b" | grep -E "FAILED|error" || true
  wait $capture || { cat "captures/$name.log"; exit 1; }
  python3 -I analyse_join.py "captures/$name.wav" | tee "captures/$name.result"
done
echo; echo "Summary (captures/*.result):"; for case in "${cases[@]}"; do IFS='|' read -r name _ <<< "$case"; printf "  %-18s %s\n" "$name" "$(cat captures/$name.result)"; done
