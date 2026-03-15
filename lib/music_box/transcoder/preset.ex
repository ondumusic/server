defmodule MusicBox.Transcoder.Preset do
  @moduledoc false

  alias MusicBox.Files.File

  defstruct [
    :id,
    :ext,
    :bitrate,
    :ffmpeg_preset,
    :mimetype,
    sample_rate: 48_000
  ]

  @type t :: %__MODULE__{
          id: atom(),
          bitrate: non_neg_integer(),
          sample_rate: non_neg_integer(),
          ffmpeg_preset: :aac | :webm,
          mimetype: String.t(),
          ext: String.t()
        }

  @spec default_id :: atom()
  def default_id, do: :default_webm

  @spec list() :: [t()]
  def list do
    [
      %__MODULE__{
        id: :mobile_aac,
        bitrate: 160,
        ffmpeg_preset: :aac,
        mimetype: "audio/aac",
        ext: "aac"
      },
      %__MODULE__{
        id: :default_aac,
        bitrate: 192,
        ffmpeg_preset: :aac,
        mimetype: "audio/aac",
        ext: "aac"
      },
      %__MODULE__{
        id: :mobile_webm,
        bitrate: 128,
        ffmpeg_preset: :webm,
        mimetype: "audio/webm",
        ext: "webm"
      },
      %__MODULE__{
        id: :default_webm,
        bitrate: 160,
        ffmpeg_preset: :webm,
        mimetype: "audio/webm",
        ext: "webm"
      }
    ]
  end

  @spec get(id :: String.t() | atom()) :: t()
  def get(id) do
    list()
    |> Enum.find(&(to_string(&1.id) == to_string(id)))
    |> case do
      nil ->
        Enum.find(list(), &(&1.id == default_id()))

      preset ->
        preset
    end
  end

  @spec ffmpeg_args(file :: File.t(), preset :: t()) :: [String.t()]
  def ffmpeg_args(%File{} = file, %__MODULE__{} = preset) do
    ["-i", file.path] ++ ffmpeg_shared_args(file, preset)
  end

  defp ffmpeg_shared_args(%File{} = file, %__MODULE__{ffmpeg_preset: :webm} = preset) do
    ~w(
        -c:a libopus -b:a #{preset.bitrate}k -f webm -ar #{preset.sample_rate} -vn
        -fflags +genpts+nobuffer -max_delay 0
        -avoid_negative_ts make_zero -vbr on
        -ss 0 -t #{file.metadata.duration}
        -cluster_time_limit 4000 -cues_to_front 1
        -v quiet -nostats
        pipe:1
      )
  end

  defp ffmpeg_shared_args(%File{} = file, %__MODULE__{ffmpeg_preset: :aac} = preset) do
    ~w(
        -c:a aac -b:a #{preset.bitrate}k -ar #{preset.sample_rate} -f adts
        -ac 2 pipe:1 -v quiet -nostats -t #{file.metadata.duration}
    )
  end
end
