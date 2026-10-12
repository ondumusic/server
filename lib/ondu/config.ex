defmodule Ondu.Config do
  @moduledoc """
  This module provides quick access to various application configuration settings.

  These settings can be adjusted through environment variables, which are read in
  the config/runtime.exs file. This module just reads those values.

  ## Application Settings
  ┌────────────────────────────────┬───────────┬───────────────────────────────────────────┐
  │      Environment Variable      │ Required? │               Description                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_URL                       │ Yes       │ The scheme and hostname used to host your │
  │                                │           │ Ondu instance.                            │
  │                                │           │ e.g. https://example.com                  │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_DATABASE_PATH             │ Yes       │ The full path to store the SQLite db file │
  │                                │           │ e.g. /data/db/ondu.db                     │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_SECRET_KEY_BASE           │ Yes       │ This is used to sign and encrypt secrets  │
  │                                │           │ and requires a minimum length of 32, but  │
  │                                │           │ 64 characters is recommended.             │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_DISABLE_WEB               │ No        │ If you only want API access you can use   │
  │                                │           │ this to disable the built-in web ui.      │
  │                                │           │ Defaults to false                         │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_STORAGE_DRIVER            │ No        │ What storage medium is hosting your       │
  │                                │           │ original music files. Either `file` or    │
  │                                │           │ `s3`. Defaults to `file`.                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_STORAGE_S3_BUCKET         │ Using S3  │ The S3 bucket name to use where your      │
  │                                │           │ original music files are stored.          │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_STORAGE_S3_REGION         │ Using S3  │ The S3 bucket AWS region.                 │
  └────────────────────────────────┴───────────┴───────────────────────────────────────────┘


  ## Transcoder Settings
  Transcoding only happens for streams/downloads when requested, by default the original
  files are always sent.

  ┌────────────────────────────────┬───────────┬───────────────────────────────────────────┐
  │      Environment Variable      │ Required? │               Description                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_TRANSCODE_CACHE_PATH      │ Yes       │ The full path to a directory where the    │
  │                                │           │ application will store transcoded files.  │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_TRANSCODE_CACHE_MAX_SIZE  │ No        │ Maximum size of the transcoded files in   │
  │                                │           │ megabytes, the oldest are removed after a │
  │                                │           │ library scan. Use 0 for no limit.         │
  │                                │           │ Defaults to 10240 (10GB)                  │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_TRANSCODE_QUEUE_SIZE      │ No        │ How many transcode requests can be sent   │
  │                                │           │ to the queue while waiting for available  │
  │                                │           │ slots (waiting for other transcodes to    │
  │                                │           │ complete first.) Defaults to 10           │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_TRANSCODE_MAX_CONCURRENCY │ No        │ How many transcodes can run at the same   │
  │                                │           │ time. Basically, how many ffmpegs can be  │
  │                                │           │ started concurrently. Defaults to 3       │
  └────────────────────────────────┴───────────┴───────────────────────────────────────────┘

  ## Artwork Settings
  Artwork is read from the artwork embedded in your media files.

  ┌────────────────────────────────┬───────────┬───────────────────────────────────────────┐
  │      Environment Variable      │ Required? │               Description                 │
  ├────────────────────────────────┼───────────┼───────────────────────────────────────────┤
  │ ONDU_ARTWORK_PATH              │ Yes       │ The full path to a directory where the    │
  │                                │           │ application will store album artwork.     │
  └────────────────────────────────┴───────────┴───────────────────────────────────────────┘
  """

  alias Ondu.Artwork
  alias Ondu.Transcoder

  @spec url() :: String.t()
  def url, do: OnduWeb.Endpoint.url()

  # Artwork settings
  @spec artwork_path() :: String.t()
  def artwork_path, do: config(Artwork, :artwork_path)

  # Transcoder settings
  @spec transcode_cache_path() :: String.t()
  def transcode_cache_path, do: config(Transcoder, :cache_path)

  @spec transcode_max_concurrency() :: non_neg_integer()
  def transcode_max_concurrency, do: config(Transcoder, :max_concurrency)

  @spec transcode_max_queue_size() :: non_neg_integer()
  def transcode_max_queue_size, do: config(Transcoder, :max_queue_size)

  @spec transcode_max_cache_size() :: pos_integer() | nil
  def transcode_max_cache_size, do: config(Transcoder, :max_cache_size)

  defp config(mod, key) do
    conf = Application.get_env(:ondu, mod) || []
    Keyword.get(conf, key)
  end
end
