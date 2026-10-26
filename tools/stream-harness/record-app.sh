#!/usr/bin/env bash
# Records whatever the Mac plays for a number of seconds and looks for a gap or a
# phase jump in it. Copy assets/album/ into a library, play the album in the app
# so the track change falls inside the recording, and read the result. Needs the
# Screen Recording permission like run-handoff.sh. Usage: record-app.sh [seconds]
set -euo pipefail
cd "$(dirname "$0")"
[ -x syscapture ] && [ syscapture -nt syscapture.swift ] || swiftc -O -Xfrontend -disable-availability-checking syscapture.swift -o syscapture -framework ScreenCaptureKit -framework AVFoundation
mkdir -p captures
name="app_$(date +%H%M%S)"
echo "recording ${1:-20}s into captures/$name.wav, play the Continuous Tone album now"
./syscapture "${1:-20}" "captures/$name.wav" > "captures/$name.log" 2>&1 || { cat "captures/$name.log"; exit 1; }
python3 -I analyse_join.py "captures/$name.wav" | tee "captures/$name.result"
