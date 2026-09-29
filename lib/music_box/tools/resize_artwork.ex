defmodule MusicBox.Tool.ResizeArtwork do
  @moduledoc false
  @behaviour MusicBox.Tool

  alias MusicBox.Artwork.Fetcher
  require Logger

  # We will limit the maximum dimensions of our image to avoid high memory usage
  @max_dimension 10_000
  @probe_timeout :timer.seconds(10)
  @resize_timeout :timer.seconds(60)

  @impl true
  def exec(opts) when is_list(opts), do: exec(Map.new(opts))

  def exec(%{album: album, path: path, variants: variants}) do
    Logger.debug("Resizing artwork for album #{album.id}, file: #{path}")

    ffmpeg_path = System.find_executable("ffmpeg") || throw(:ffmpeg_not_found)
    ffprobe_path = System.find_executable("ffprobe") || throw(:ffprobe_not_found)

    outputs =
      for {variant_path, size} <- variants,
          do: {variant_path, Fetcher.tmp_path(variant_path), size}

    with true <- File.exists?(path),
         {:ok, dimensions} <- probe_dimensions(ffprobe_path, path),
         :ok <- check_dimensions(dimensions),
         :ok <- mkdir_outputs(outputs),
         {_stdout, 0} <-
           MusicBox.Tool.cmd(ffmpeg_path, ffmpeg_args(path, outputs),
             timeout: @resize_timeout,
             stderr_to_stdout: true
           ),
         :ok <- rename_outputs(outputs) do
      {:ok, dimensions}
    else
      false ->
        Logger.error("Failed to resize artwork for album #{album.id}, file not found?")
        {:error, :file_not_found}

      {:error, :too_large} ->
        Logger.warning("Artwork of album #{album.id} is too large to resize (file: #{path})")
        {:error, :too_large}

      {:error, reason} ->
        cleanup_outputs(outputs)
        Logger.error("Failed to resize artwork for album #{album.id} (reason: #{reason})")
        {:error, :failed_to_resize}

      {_stdout, exitcode} ->
        cleanup_outputs(outputs)
        Logger.error("Failed to resize artwork for album #{album.id}, exit code #{exitcode}")
        {:error, :failed_to_resize}
    end
  end

  defp probe_dimensions(ffprobe_path, path) do
    args =
      ~w(-v quiet -select_streams v:0 -show_entries stream=width,height -of csv=p=0) ++ [path]

    with {stdout, 0} <- MusicBox.Tool.cmd(ffprobe_path, args, timeout: @probe_timeout),
         [width, height] <- stdout |> String.trim() |> String.split(","),
         {width, ""} when width > 0 <- Integer.parse(width),
         {height, ""} when height > 0 <- Integer.parse(height) do
      {:ok, %{width: width, height: height}}
    else
      _ -> {:error, :probe_failed}
    end
  end

  defp check_dimensions(%{width: width, height: height}) do
    if max(width, height) > @max_dimension, do: {:error, :too_large}, else: :ok
  end

  defp mkdir_outputs(outputs) do
    outputs
    |> Enum.map(fn {path, _tmp_path, _size} -> Path.dirname(path) end)
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn dir, :ok ->
      case File.mkdir_p(dir) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp rename_outputs(outputs) do
    Enum.reduce_while(outputs, :ok, fn {path, tmp_path, _size}, :ok ->
      case File.rename(tmp_path, path) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp cleanup_outputs(outputs) do
    for {_path, tmp_path, _size} <- outputs, do: File.rm(tmp_path)
  end

  defp ffmpeg_args(path, outputs) do
    outputs = Enum.with_index(outputs, 1)
    split = "[0:v]split=#{length(outputs)}" <> Enum.map_join(outputs, fn {_, i} -> "[in#{i}]" end)

    scales =
      for {{_path, _tmp_path, size}, i} <- outputs,
          do: "[in#{i}]" <> square_filter(size) <> "[out#{i}]"

    maps =
      Enum.flat_map(outputs, fn {{_path, tmp_path, _size}, i} ->
        ["-map", "[out#{i}]", "-q:v", "2", "-update", "1", tmp_path]
      end)

    ["-nostdin", "-y", "-i", path, "-filter_complex", Enum.join([split | scales], ";")] ++ maps
  end

  # Fit within `size` without upscaling, then pad to a square with white.
  defp square_filter(size) do
    "scale='min(iw,#{size})':'min(ih,#{size})':force_original_aspect_ratio=decrease:flags=lanczos," <>
      "format=yuv444p,pad='max(iw,ih)':'max(iw,ih)':'(ow-iw)/2':'(oh-ih)/2':color=white," <>
      "format=yuv420p"
  end
end
