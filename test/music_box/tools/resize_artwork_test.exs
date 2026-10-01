defmodule MusicBox.Tool.ResizeArtworkTest do
  use ExUnit.Case, async: true

  alias MusicBox.Tool.ResizeArtwork

  @tmp_path Path.absname("./tmp/test/resize_artwork")

  setup context do
    dir = Path.join(@tmp_path, "#{context.line}")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    [dir: dir]
  end

  describe "exec/1" do
    test "fits non-square artwork within each variant and pads it to a white square", %{dir: dir} do
      source = red_image(dir, 1215, 1030)

      assert {:ok, %{width: 1215, height: 1030}} = resize(source, dir)

      assert dimensions(Path.join(dir, "thumbnail.jpg")) == {128, 128}
      assert dimensions(Path.join(dir, "large.jpg")) == {640, 640}

      large = Path.join(dir, "large.jpg")
      assert white?(pixel(large, 320, 5))
      assert red?(pixel(large, 320, 320))
      assert red?(pixel(large, 5, 320))
    end

    @tag capture_log: true
    test "refuses artwork larger than 10000 pixels", %{dir: dir} do
      source = red_image(dir, 10_001, 10)

      assert {:error, :too_large} = resize(source, dir)
      assert Path.wildcard(Path.join(dir, "*.jpg")) == []
    end

    test "does not upscale small artwork", %{dir: dir} do
      source = red_image(dir, 100, 60)

      assert {:ok, %{width: 100, height: 60}} = resize(source, dir)

      assert dimensions(Path.join(dir, "thumbnail.jpg")) == {100, 100}
      assert dimensions(Path.join(dir, "large.jpg")) == {100, 100}
    end

    test "pads odd sized jpeg artwork", %{dir: dir} do
      source = red_image(dir, 531, 459, "jpg")

      assert {:ok, %{width: 531, height: 459}} = resize(source, dir)

      assert dimensions(Path.join(dir, "thumbnail.jpg")) == {128, 128}
      assert dimensions(Path.join(dir, "large.jpg")) == {531, 531}
    end

    @tag capture_log: true
    test "returns an error for files that are not images", %{dir: dir} do
      source = Path.join(dir, "source")
      File.write!(source, :crypto.strong_rand_bytes(128))

      assert {:error, :failed_to_resize} = resize(source, dir)
      assert File.ls!(dir) == ["source"]
    end

    test "keeps the aspect ratio with fit: :shortest_side", %{dir: dir} do
      source = red_image(dir, 1215, 1030)

      assert {:ok, %{width: 1215, height: 1030}} = resize(source, dir, :shortest_side)

      assert dimensions(Path.join(dir, "thumbnail.jpg")) == {151, 128}
      assert dimensions(Path.join(dir, "large.jpg")) == {755, 640}
    end

    test "does not upscale or change odd sizes with fit: :shortest_side", %{dir: dir} do
      source = red_image(dir, 531, 459, "jpg")

      assert {:ok, _dimensions} = resize(source, dir, :shortest_side)

      assert dimensions(Path.join(dir, "thumbnail.jpg")) == {148, 128}
      assert dimensions(Path.join(dir, "large.jpg")) == {531, 459}
    end

    @tag capture_log: true
    test "returns an error when the source does not exist", %{dir: dir} do
      assert {:error, :file_not_found} = resize(Path.join(dir, "missing"), dir)
    end
  end

  defp resize(source, dir, fit \\ :square) do
    ResizeArtwork.exec(
      id: "artwork-id",
      path: source,
      fit: fit,
      variants: [
        {Path.join(dir, "thumbnail.jpg"), 128},
        {Path.join(dir, "large.jpg"), 640}
      ]
    )
  end

  defp red_image(dir, width, height, ext \\ "png") do
    path = Path.join(dir, "source.#{ext}")

    # Force rgb24 on the source: older ffmpeg (6.x) rounds odd sizes down to even when the
    # color source negotiates a chroma subsampled format. Keep jpegs 4:2:0 like real artwork.
    pix_fmt = if ext == "jpg", do: ~w(-pix_fmt yuvj420p), else: []

    ffmpeg(
      ~w(-y -v quiet -f lavfi -i color=c=red:s=#{width}x#{height},format=rgb24 -frames:v 1 -update 1) ++
        pix_fmt ++ [path]
    )

    path
  end

  defp dimensions(path) do
    {stdout, 0} =
      System.cmd(
        "ffprobe",
        ~w(-v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0) ++ [path]
      )

    [width, height] = stdout |> String.trim() |> String.split(",")
    {String.to_integer(width), String.to_integer(height)}
  end

  defp pixel(path, x, y) do
    <<r, g, b>> =
      ffmpeg(
        ["-i", path] ++
          ~w(-vf format=rgb24,crop=1:1:#{x}:#{y} -f rawvideo -pix_fmt rgb24 -v quiet pipe:1)
      )

    {r, g, b}
  end

  defp ffmpeg(args) do
    {stdout, 0} = System.cmd("ffmpeg", args)
    stdout
  end

  defp white?({r, g, b}), do: r > 240 and g > 240 and b > 240
  defp red?({r, g, b}), do: r > 200 and g < 60 and b < 60
end
