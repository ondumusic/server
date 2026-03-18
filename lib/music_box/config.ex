defmodule MusicBox.Config do
  @moduledoc false

  alias MusicBox.Transcoder
  alias MusicBox.Artwork

  def url, do: MusicBoxWeb.Endpoint.url()

  def artwork_path, do: config(Artwork, :artwork_path)
  def artwork_musicbrainz?, do: config(Artwork, :use_music_brainz)
  def artwork_custom_api, do: config(Artwork, :custom_api)

  def transcode_cache_path, do: config(Transcoder, :cache_path)
  def transcode_max_concurrency, do: config(Transcoder, :max_concurrency)
  def transcode_max_queue, do: config(Transcoder, :max_queue_size)

  defp config(mod, key) do
    conf = Application.get_env(:music_box, mod) || []
    Keyword.get(conf, key)
  end
end
