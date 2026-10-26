# Stream harness

Scripts to check how real players handle what the server produces, instead
of listening by ear. Nothing here runs in `mix test`, it is for validating
format and streaming decisions on the platforms the apps run on.

```
./check-env.sh      # what this machine can run, and what is missing
./make-assets.sh    # generates assets/: test files in every format
./run-avplayer.sh   # macOS only: AVPlayer duration, seeking, gapless per format
./run-handoff.sh    # macOS only: records the real output across a transition (needs Screen Recording permission)
./check-runner-ffmpeg.sh  # the same ffmpeg behaviours inside the Docker runner image (podman or docker)
python3 -I rangeserver.py 8765 &
node web-probe.mjs 8765   # browsers via playwright (install browsers first)
node web-live.mjs "long.ogg_opus_padded.opus?live=300000&tail=131072"  # Chromium on a transcode in progress
```

## What it measures

- **Delivery modes.** `rangeserver.py` serves `assets/` like the server does
  for a finished transcode (Content-Length and ranges) and, with `?chunked=1`,
  like a live transcode with no known size. `?kbps=N` throttles, to mimic a
  slow encoder.
- **Seeking and duration.** `avprobe probe <url>` waits for the item to be
  ready, prints the duration the player sees and whether a seek to 60%
  completes.
- **Gapless.** `avprobe gapless <url1> <url2>` queues the two halves of one
  continuous tone in `AVQueuePlayer` and counts, through an audio tap, the
  signal frames rendered per item. Both must render exactly 220500 frames at
  44.1kHz (240000 at 48kHz). More means untrimmed priming or padding, less
  means the end is cut: either is an audible gap.
- **Handoff.** The tap only sees frames, not when they reach the speaker, so a
  gap the player inserts in time between two items is invisible to it.
  `run-handoff.sh` records the system output with `syscapture` while the pair
  plays and `analyse_join.py` looks for a dip or an irregular zero-crossing
  interval in the tone. It also plays mixed pairs, since a real queue can hold
  an older cached ADTS or downloaded AAC track next to an Ogg stream.

## Findings so far (macOS 27, ffmpeg 8.1)

| format | ranged | chunked | gapless |
| --- | --- | --- | --- |
| Ogg Opus (`default_ogg`) | plays, seeks, duration is an estimate | plays, no duration | exact |
| AAC M4A (`default_aac`) | plays, seeks, reads the file tail first | fails | exact |
| ADTS (`default_adts`) | plays, duration is an estimate | plays, no duration | +6 ms per track |
| WebM Opus (`default_opus`) | fails | fails | - |
| fragmented MP4 | plays, seeks | fails | -48 ms per track |
| Opus in MP4 | plays | fails | exact |

Clients should take the duration from the API, players estimate it for
Ogg and ADTS.

Measured at the real output with `run-handoff.sh` (the tap in `avprobe`
costs a 440 ms handoff by itself, so only the no-tap cases count):

| pair | at the join |
| --- | --- |
| Ogg to Ogg, over HTTP, padded, or local | nothing: no dip, no phase jump |
| AAC M4A to AAC M4A | 3 ms hole |
| ADTS to ADTS | 38 ms |
| AAC to Ogg or Ogg to AAC | 77 to 110 ms (sample rate change) |

The only Ogg imperfection is the encoder's first frame after a join, about
31 dB below a pure tone for 10 ms (`residual.py`). Only a lead-in of the
real previous track's audio removes it; mirrored or silent lead-ins and
shorter frames make it worse.

The padding is empty Ogg pages, not zeros. Readers find the duration by
looking for the last page near the end, and ffmpeg (so Chrome) gives up
after 64 KB: a 300 KB tail of zeros loses the duration, the same tail of
empty pages carrying the last granule position keeps it exact. AVPlayer
treats both the same (`oggpad.py` builds either; `make-assets.sh` makes
`*_padded` and `*_zeros` variants).

Chromium and ExoPlayer read the end of an Ogg file before playing, and
Chromium asks for it from a 32 KB boundary, up to 98 KB before the end.
On a transcode in progress that request waited for the whole transcode:
with the harness server simulating one (`?live=`), Chromium did not start
within 12 s. With the last 64 KB served early it started after 2.2 s,
with the last 128 KB after 13 ms, which is what the server now does.

What did click on real albums was the source, not the player: ffmpeg drops
the encoder delay of an AAC source but keeps its end padding (456 samples on
one Apple Music track, 10 ms once resampled), so every transcode ended in
padding. The server now cuts it, see `Ondu.Transcoder.Trim`. MP3 with a LAME
header and the lossless and Ogg formats are trimmed by ffmpeg itself.

## Not covered

- Older iOS/macOS versions: run `run-avplayer.sh` on the oldest supported
  version, Opus support in AVFoundation is newer than AAC.
- Android: ExoPlayer needs an instrumented test in the Android app using the
  same assets. Expected from its extractors: Ogg Opus gapless and seekable
  with a known length, Matroska unseekable without cues, chunked unseekable.
