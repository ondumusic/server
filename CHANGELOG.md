# CHANGELOG

## Unreleased
- [Added] The Sync API now supports client/server schema version definitions
- [Fixed] API now validates sync cursors instead of just raising errors
- [Added] Web: added transcoding options to playback settings page
- [Added] `GET /api/info` added list of transcoding presets
- [Added] API now properly handles the `Accept-Language` header
- [Added] Web: the server version is now shown in the settings sidebar
- [Fixed] Web: the hover-play icon on track rows can now be clicked to start playback
- [Fixed] Web: the artist count on the library page now only counts artists with albums
- [Fixed] Web: artwork issues now clear once the artwork is processed after a rescan
- [Fixed] `GET /api/sync` answers 400 instead of 500 for a cursor the server did not issue, and for an invalid `limit`
- [Added] `GET /api/sync` takes a `schemaVersion`, the version of the entities as the client stores them. All entities are synced again when it, or the server's, changed since the cursor was issued. Existing cursors trigger one such sync.

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
