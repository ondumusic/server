# CHANGELOG

## Unreleased
- [Added] `default_ogg` and `mobile_ogg` transcoding presets (Opus in Ogg): gapless, seekable and served with a real `Content-Length` while still transcoding. They are the default now.
- [Changed] AAC transcodes no longer get a hand written edit list, ffmpeg's own is what players use
- [Removed] The `adts`, `aac` and WebM `opus` presets and the transcode prepare endpoint, the apps ask for the Ogg presets
- [Fixed] Range requests on transcodes ending exactly on a chunk boundary were one byte short
- [Fixed] Transcodes of AAC sources carried the encoder padding at their end, a click at every track change of a gapless album

## 1.0.0-rc.3 - 2026-10-22
- [Changed] redesigned the web ui ([#10](https://github.com/ondumusic/server/pull/10))

## 1.0.0-rc.2 - 2026-10-19
- [Fixed] Albums with different track release years now use the most common one
- [Fixed] Annotation data keys are no longer converted to snake_case
- [Added] Retagged and re-encoded files now keep their play history
- [Added] Renamed albums and artists now keep their artwork and annotations
- [Changed] Improved detection of moved, replaced and renamed files

## 1.0.0-rc.1 - 2026-10-13
This is the first release of the Ondu Server.
