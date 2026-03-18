defmodule MusicBox.Config do
  @moduledoc """
  This module provides quick access to various application configuration settings.

  These settings can be adjusted through environment variables, which are read in
  the config/runtime.exs file. This module just reads those values.

  ## Application Settings
  ┌────────────────────────────────┬───────────┬───────────────────────────────────────────┐
  │      Environment Variable      │ Required? │               Description                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_URL                         │ Yes       │ The scheme and hostname used to host your │
  │                                │           │ MusicBox instance.                        │
  │                                │           │ e.g. https://example.com                  │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_DATABASE_PATH               │ Yes       │ The full path to store the SQLite db file │
  │                                │           │ e.g. /data/db/musicbox.db                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_SECRET_KEY_BASE             │ Yes       │ This is used to sign and encrypt secrets  │
  │                                │           │ and requires a minimum length of 32, but  │
  │                                │           │ 64 characters is recommended.             │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_DISABLE_WEB                 │ No        │ If you only want API access you can use   │
  │                                │           │ this to disable the built-in web ui.      │
  │                                │           │ Defaults to false                         │
  └────────────────────────────────┴───────────┴───────────────────────────────────────────┘



  ## Transcoder Settings
  Transcoding only happens for streams/downloads when requested, by default the original
  files are always sent.

  ┌────────────────────────────────┬───────────┬───────────────────────────────────────────┐
  │      Environment Variable      │ Required? │               Description                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_TRANSCODE_CACHE_PATH        │ Yes       │ The full path to a directory where the    │
  │                                │           │ application will store transcoded files.  │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_TRANSCODE_QUEUE_SIZE        │ No        │ How many transcode requests can be sent   │
  │                                │           │ to the queue while waiting for available  │
  │                                │           │ slots (waiting for other transcodes to    │
  │                                │           │ complete first.) Defaults to 10           │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_TRANSCODE_MAX_CONCURRENCY   │ No        │ How many transcodes can run at the same   │
  │                                │           │ time. Basically, how many ffmpegs can be  │
  │                                │           │ started concurrently. Defaults to 3       │
  └────────────────────────────────┴───────────┴───────────────────────────────────────────┘

  ## Artwork Settings
  By default it will attempt to get embedded artwork from your media files. If
  none is found it can try to use either a custom api or MusicBrainz.

  ┌────────────────────────────────┬───────────┬───────────────────────────────────────────┐
  │      Environment Variable      │ Required? │               Description                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_ARTWORK_PATH                │ Yes       │ The full path to a directory where the    │
  │                                │           │ application will store album artwork.     │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_ARTWORK_CUSTOM_API          │ No        │ When configured this can be used to find  │
  │                                │           │ artwork based on artist/album/track info  │
  │                                │           │ but requires a custom implementation.     │
  │                                │           │ e.g. http://localhost:4000/find_artwork   │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ MB_ARTWORK_ENABLE_MUSICBRAINZ  │ No        │ Allow automated lookups to MusicBrainz    │
  │                                │           │ to find artwork. Can be inaccurate so it  │
  │                                │           │ is disabled by default.                   │
  └────────────────────────────────┴───────────┴───────────────────────────────────────────┘
  """

  alias MusicBox.Artwork
  alias MusicBox.Transcoder

  @spec url() :: String.t()
  def url, do: MusicBoxWeb.Endpoint.url()

  # Artwork settings
  @spec artwork_path() :: String.t()
  def artwork_path, do: config(Artwork, :artwork_path)

  @spec artwork_musicbrainz?() :: boolean()
  def artwork_musicbrainz?, do: config(Artwork, :use_music_brainz)

  @spec artwork_custom_api() :: String.t() | nil
  def artwork_custom_api, do: config(Artwork, :custom_api)

  # Transcoder settings
  @spec transcode_cache_path() :: String.t()
  def transcode_cache_path, do: config(Transcoder, :cache_path)

  @spec transcode_max_concurrency() :: non_neg_integer()
  def transcode_max_concurrency, do: config(Transcoder, :max_concurrency)

  @spec transcode_max_queue() :: non_neg_integer()
  def transcode_max_queue, do: config(Transcoder, :max_queue_size)

  defp config(mod, key) do
    conf = Application.get_env(:music_box, mod) || []
    Keyword.get(conf, key)
  end
end
