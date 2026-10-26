#!/usr/bin/env bash
# Generates the test assets in assets/: two sample-exact halves (5s each,
# 220500 samples at 44.1kHz) of one continuous 440Hz tone, in every format
# the server can produce, plus a 180s file per format for seek tests. A gap
# or untrimmed priming at the join between the halves is then measurable.
set -euo pipefail
cd "$(dirname "$0")"
./check-env.sh >/dev/null || { ./check-env.sh; exit 1; }
mkdir -p assets && cd assets

ffmpeg -nostdin -v error -y -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=10" -af "aformat=channel_layouts=stereo" -c:a pcm_s16le full.wav
ffmpeg -nostdin -v error -y -i full.wav -af "atrim=start_sample=0:end_sample=220500" -c:a flac h1.flac
ffmpeg -nostdin -v error -y -i full.wav -af "atrim=start_sample=220500:end_sample=441000" -c:a flac h2.flac
# 180s of pink noise and a tone, behaves like music for bitrate purposes
ffmpeg -nostdin -v error -y -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=180" -f lavfi -i "anoisesrc=color=pink:sample_rate=44100:duration=180:amplitude=0.3" -filter_complex "[0:a][1:a]amix=inputs=2,aformat=channel_layouts=stereo" -c:a flac long.flac

encode() { # name, input, output, ffmpeg args...
  local name=$1 input=$2 output=$3; shift 3
  if [[ "$output" == *pipe* ]]; then
    ffmpeg -nostdin -v error -y -i "$input" "$@" -f "${output#pipe:}" pipe:1 > "$name"
  else
    ffmpeg -nostdin -v error -y -i "$input" "$@" "$name"
  fi
}
for src in h1 h2 long; do
  # what the server presets produce
  encode $src.ogg_opus.opus $src.flac pipe:ogg -c:a libopus -b:a 192k -vbr off -ar 48000 -map_metadata -1        # default_ogg
  encode $src.aac.m4a       $src.flac mp4      -c:a aac -b:a 256k -ar 44100                                        # default_aac (before iTunSMPB injection)
  encode $src.adts.aac      $src.flac pipe:adts -c:a aac -b:a 256k -ar 44100                                       # default_adts
  encode $src.webm_opus.webm $src.flac pipe:webm -c:a libopus -b:a 192k -ar 48000 -cluster_time_limit 4000        # default_opus
  # alternatives worth comparing against
  encode $src.fmp4.m4a      $src.flac pipe:mp4 -c:a aac -b:a 256k -movflags +frag_keyframe+empty_moov+delay_moov+default_base_moof -frag_duration 2000000
  encode $src.opus_mp4.mp4  $src.flac mp4      -c:a libopus -b:a 192k
done
# a page for the browser probes
cat > play.html <<'HTML'
<!doctype html><title>probe</title><audio id=a controls muted></audio>
HTML
# padded oggs, as the server serves them: the promised size is larger than the file.
# 300 KB is far past the 64 KB in which ffmpeg (and Chrome) look for the last page,
# which is why the server pads with empty pages (oggpad.py) rather than zeros.
for src in h1 h2 long; do
  size=$(( $(stat -f%z $src.ogg_opus.opus 2>/dev/null || stat -c%s $src.ogg_opus.opus) + 300000 ))
  python3 -I ../oggpad.py $src.ogg_opus.opus $src.ogg_opus_padded.opus $size
  python3 -I ../oggpad.py $src.ogg_opus.opus $src.ogg_opus_zeros.opus $size zeros
done
ls -l

# A two-track album of one continuous tone, for the library of a test server: play
# it in an app and record the output with record-app.sh. 20s per track leaves the
# app time to line up the next one. The tracks are sample-exact halves, like h1/h2.
mkdir -p album
ffmpeg -nostdin -v error -y -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=40" -af "aformat=channel_layouts=stereo" -c:a pcm_s16le album_full.wav
ffmpeg -nostdin -v error -y -i album_full.wav -af "atrim=start_sample=0:end_sample=882000" -c:a flac \
  -metadata artist="Harness" -metadata album_artist="Harness" -metadata album="Continuous Tone" -metadata title="Tone, first half" -metadata track=1 -metadata date=2026 "album/01 - Tone, first half.flac"
ffmpeg -nostdin -v error -y -i album_full.wav -af "atrim=start_sample=882000:end_sample=1764000" -c:a flac \
  -metadata artist="Harness" -metadata album_artist="Harness" -metadata album="Continuous Tone" -metadata title="Tone, second half" -metadata track=2 -metadata date=2026 "album/02 - Tone, second half.flac"
ls -l album
