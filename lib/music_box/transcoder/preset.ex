defmodule MusicBox.Transcoder.Preset do
  @moduledoc """
  This module defines all possible presets and ffmpeg argument helper functions.

  ## Currently defined presets
  ┌─────────────────────┬───────┬─────────┬─────────────┬─────────┬───────────┬────────────┐
  │       Preset        │ Codec │ Bitrate │ Sample Rate │ Format  │ Extension │    MIME    │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┤
  │ Default AAC (M4A)   │ AAC   │ 256k    │ 44100       │ -f mp4  │ .m4a      │ audio/mp4  │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┤
  │ Default ADTS stream │ AAC   │ 256k    │ 44100       │ -f adts │ .aac      │ audio/aac  │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┤
  │ Default Opus        │ Opus  │ 192k    │ 48000       │ -f webm │ .webm     │ audio/webm │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┤
  │ Mobile AAC (M4A)    │ AAC   │ 128k    │ 44100       │ -f mp4  │ .m4a      │ audio/mp4  │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┤
  │ Mobile ADTS stream  │ AAC   │ 128k    │ 44100       │ -f adts │ .aac      │ audio/aac  │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┤
  │ Mobile Opus         │ Opus  │ 96k     │ 48000       │ -f webm │ .webm     │ audio/webm │
  └─────────────────────┴───────┴─────────┴─────────────┴─────────┴───────────┴────────────┘

  ## About AAC/ADTS
  This seems a bit confusing but the reasoning behind it is a best attempt at
  having working gapless playback support. However doing this requires a two-step
  transcoding pipeline, where after converting the file we also need to inject a
  iTunSMPB metatag into the file. This seems to yield the best results, however
  also means we can't stream the file until this is processed.

  So iOS clients should ideally try to use the AAC version (which should include
  the iTunSMPB metadata) for downloads, but could revert to ADTS for streaming so
  the playback happens as soon as possible. (There are always possible reasons
  for delays, like a full transcoding queue). This does still mean there might be
  a more noticeable gap between sequential tracks while streaming, compared to
  downloads. It would be nice if AVPlayer just supported opus too.

  I still feel like it is not perfect but at this point this combination of
  presets is the best I can do, for now.
  """

  alias MusicBox.Files.File
  alias MusicBox.Storage
  alias MusicBox.Transcoder.Utils

  defstruct [
    :id,
    :ext,
    :bitrate,
    :ffmpeg_preset,
    :mimetype,
    :sample_rate,
    streamable?: true
  ]

  @type t :: %__MODULE__{
          id: atom(),
          bitrate: non_neg_integer(),
          sample_rate: non_neg_integer(),
          ffmpeg_preset: :aac | :adts | :opus,
          streamable?: boolean(),
          mimetype: String.t(),
          ext: String.t()
        }

  @spec default_preset :: t()
  def default_preset, do: Enum.find(list(), &(&1.id == :default_opus))

  @spec list() :: [t()]
  def list do
    [
      %__MODULE__{
        id: :default_aac,
        bitrate: 256,
        sample_rate: 44_100,
        ffmpeg_preset: :aac,
        streamable?: false,
        mimetype: "audio/mp4",
        ext: "m4a"
      },
      %__MODULE__{
        id: :mobile_aac,
        bitrate: 128,
        sample_rate: 44_100,
        ffmpeg_preset: :aac,
        streamable?: false,
        mimetype: "audio/mp4",
        ext: "m4a"
      },
      %__MODULE__{
        id: :default_adts,
        bitrate: 256,
        sample_rate: 44_100,
        ffmpeg_preset: :adts,
        mimetype: "audio/aac",
        ext: "aac"
      },
      %__MODULE__{
        id: :mobile_adts,
        bitrate: 128,
        sample_rate: 44_100,
        ffmpeg_preset: :adts,
        mimetype: "audio/aac",
        ext: "aac"
      },
      %__MODULE__{
        id: :default_opus,
        bitrate: 192,
        sample_rate: 48_000,
        ffmpeg_preset: :opus,
        mimetype: "audio/webm",
        ext: "webm"
      },
      %__MODULE__{
        id: :mobile_opus,
        bitrate: 96,
        sample_rate: 48_000,
        ffmpeg_preset: :opus,
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
      nil -> default_preset()
      preset -> preset
    end
  end

  @spec ffmpeg_args(file :: File.t(), preset :: t()) :: [String.t()]
  def ffmpeg_args(%File{} = file, %__MODULE__{} = preset) do
    uri = Storage.get_uri(file.path)
    args = ["-i", uri] ++ ffmpeg_shared_args(file, preset)

    if preset.streamable? do
      args
    else
      tmp_output_file = Utils.tmp_file_path(file.id, preset)
      args ++ [tmp_output_file]
    end
  end

  @spec bitrate(file :: File.t(), preset :: t()) :: non_neg_integer()
  def bitrate(%{metadata: %{bitrate: bitrate}}, preset) when is_integer(bitrate),
    do: min(bitrate, preset.bitrate)

  def bitrate(_file, %{bitrate: bitrate}),
    do: bitrate

  @spec sample_rate(file :: File.t(), preset :: t()) :: non_neg_integer()
  def sample_rate(%{metadata: %{sample_rate: sample_rate}}, preset) when is_integer(sample_rate),
    do: min(sample_rate, preset.sample_rate)

  def sample_rate(_file, %{sample_rate: sample_rate}),
    do: sample_rate

  @spec audio_channels(file :: File.t(), preset :: t()) :: non_neg_integer()
  def audio_channels(%{metadata: %{audio_channels: audio_channels}}, _preset)
      when is_integer(audio_channels),
      do: min(2, audio_channels)

  def audio_channels(_file, _preset),
    do: 2

  defp ffmpeg_shared_args(%File{} = file, %__MODULE__{ffmpeg_preset: :opus} = preset) do
    bitrate = bitrate(file, preset)
    audio_channels = audio_channels(file, preset)
    # NOTE: libopus has limited options for sample rate so we just use fixed 48000

    ~w(
        -c:a libopus -b:a #{bitrate}k -f webm -ar 48000 -vn
        -fflags +genpts+nobuffer -max_delay 0
        -avoid_negative_ts make_zero -vbr on
        -ac #{audio_channels}
        -ss 0 -t #{file.metadata.duration}
        -cluster_time_limit 4000 -cues_to_front 1
        -y -v quiet -nostats
        pipe:1
      )
  end

  defp ffmpeg_shared_args(%File{} = file, %__MODULE__{ffmpeg_preset: :aac} = preset) do
    bitrate = bitrate(file, preset)
    sample_rate = sample_rate(file, preset)
    audio_channels = audio_channels(file, preset)

    ~w(
        -c:a aac -b:a #{bitrate}k -f mp4 -ar #{sample_rate} -vn
        -ac #{audio_channels}
        -y -v error -nostats
    )
  end

  defp ffmpeg_shared_args(%File{} = file, %__MODULE__{ffmpeg_preset: :adts} = preset) do
    bitrate = bitrate(file, preset)
    sample_rate = sample_rate(file, preset)
    audio_channels = audio_channels(file, preset)

    ~w(
        -c:a aac -b:a #{bitrate}k -f adts -ar #{sample_rate} -vn
        -ac #{audio_channels} -t #{file.metadata.duration}
        -y -v quiet -nostats
        pipe:1
    )
  end
end
