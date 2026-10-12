# Ondu Server
The self-hosted music server for [Ondu](https://ondumusic.com).

## Why Ondu?
I wanted the ease of use of music streaming apps for my owned music library.
The existing open-source options are great, but for me often felt too technical
and I happened to have some free time, so thought it was a nice little project.

As most music projects, this heavily depends on [ffmpeg](https://ffmpeg.org).

## Goals
- **Music directory is the source of truth**
  All the metadata and artwork will come from the music files (and potential
  cover.jpg files, when present). This should be read-only.
- **Private by design**
  There is no use of telemetry, analytics, external accounts or third-party
  metadata services included.
- **Offline-first apps**
  The server syncs the library metadata with the official apps to provide a
  fast experience with local search.
- **Downloads**
  The apps can download original or transcoded tracks, and optionally you can
  automatically download newly added music too.
- **OpenAPI documentation**
  Opens up your library to do whatever you want, maybe automate playlist
  creation? It even includes annotations as a simple KV store for your scripts
  so you can easily persist some data too.
- **Transcoding support**
  It includes various transcoding presets, which is mostly useful to save
  on bandwidth (or storage for downloads).

## Quick start
Ondu Server runs as a single Docker container, with SQLite as its database.

```yaml
services:
  ondu:
    image: ghcr.io/ondumusic/server:latest
    restart: unless-stopped
    ports:
      - "4000:4000"
    environment:
      ONDU_URL: https://music.example.com
    volumes:
      - /path/to/your/music:/music:ro
      - ./data:/data
```

See the [setup guide](https://ondumusic.com/setup.html) for reverse proxies and
all settings.

> **NOTE:** The server starts in onboarding mode asking you to create your
> user account and setup the library. So ideally don't start the server and
> leave it publicly accessible without setting it up immediately yourself.

## Good to know
- **Backups**
  Whilst the music directory is the source of truth and the most important thing
  to backup, I recommend backing up `/data` volume too as this will contain the
  database (playlist, play history) and any uploaded artist images
- **Forgot your password**
  You can reset your password by running:
  `docker exec <container> bin/reset-password <username>`
- **Login attempts**
  These are limited to 10 failures per 15 minutes, restarting the container will
  reset the limit and allow login again.

## Web UI
It comes with a Web UI that syncs to IndexedDB, but I will admit it is not
feature complete as I shifted priority to the native apps which are what I
use myself. I have yet to decide what to do with the Web UI, considering
making it more into admin/management only.

You can disable it with `ONDU_DISABLE_WEB=1`, but only do this after
completing onboarding so you can configure your account and music library first.

## API
The API is documented at `/docs` on your server (OpenAPI at `/openapi`).

You can disable these endpoints with `ONDU_DISABLE_DOCS=1`.

> **NOTE:** I am aware of existing API specs like Subsonic, Navidrome, etc but
> I don't really expect this project to take off for anyone but myself and
> wanted the flexibility of supporting my own.

## Development
Local development requires Elixir and PNPM.

- Run `mix setup` to install and set up dependencies
- Start the server with `iex -S mix phx.server`

Then visit [`localhost:4000`](http://localhost:4000) in your browser.

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License
Ondu is distributed under the terms of the MIT license.

See [LICENSE](LICENSE) for details.
