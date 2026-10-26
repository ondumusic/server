# CHANGELOG

## Unreleased
nothing

## 1.0.0-rc.4 - 2026-10-26
- [Changed] replace existing transcoding with ogg opus ([#11](https://github.com/ondumusic/server/pull/11))
- [Added] `default_ogg` and `mobile_ogg` transcoding presets (Opus in Ogg)
- [Removed] The `adts`, `aac` and WebM `opus` presets and the transcode prepare endpoint
- [Changed] API version 2, apps are told to update
- [Changed] Refuse unknown transcoding presets
- [Changed] The end of a transcode is served before it is encoded (players that read a file's end first (e.g. Android, Chrome) start immediately instead of post-transcode)
- [Fixed] Range requests on transcodes ending exactly on a chunk boundary were one byte short
- [Fixed] AAC sources carried the encoder padding at their end

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
