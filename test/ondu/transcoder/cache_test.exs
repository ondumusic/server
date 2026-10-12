defmodule Ondu.Transcoder.CacheTest do
  use ExUnit.Case, async: false

  alias Ondu.Transcoder.Cache
  alias Ondu.Transcoder.{Preset, Utils}

  setup do
    cache_path = Ondu.Config.transcode_cache_path()
    File.rm_rf!(cache_path)

    file_id = Ecto.UUID.generate()
    preset = Preset.default_preset()
    [file_id: file_id, preset: preset, path: Cache.cache_file_path(file_id, preset)]
  end

  test "stores the transcode", %{file_id: file_id, preset: preset, path: path} do
    assert :ok = Cache.persist(file_id, preset, fn -> ["a", "b"] end)
    assert File.read!(path) == "ab"
    assert File.ls!(Utils.tmp_dir()) == []
  end

  test "keeps an existing transcode", %{file_id: file_id, preset: preset, path: path} do
    :ok = Cache.persist(file_id, preset, fn -> ["a"] end)

    assert {:error, :already_exists} = Cache.persist(file_id, preset, fn -> ["b"] end)
    assert File.read!(path) == "a"
  end

  test "never stores an incomplete transcode", %{file_id: file_id, preset: preset, path: path} do
    chunks =
      Stream.map([1, 2], fn
        1 -> "a"
        2 -> raise "interrupted"
      end)

    assert_raise RuntimeError, fn -> Cache.persist(file_id, preset, fn -> chunks end) end
    refute File.exists?(path)
    assert {:error, :not_found} = Cache.get_meta(file_id, preset)
  end
end
