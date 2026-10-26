defmodule Ondu.Transcoder.Preset do
  @moduledoc """
  This module defines all possible presets and ffmpeg argument helper functions.

  ## Currently defined presets
  ┌─────────────────────┬───────┬─────────┬─────────────┬─────────┬───────────┬────────────┬────────────┐
  │       Preset        │ Codec │ Bitrate │ Sample Rate │ Format  │ Extension │    MIME    │ Exact size │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Default Ogg (Opus)  │ Opus  │ 192k    │ 48000       │ -f ogg  │ .opus     │ audio/ogg  │ yes        │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Mobile Ogg (Opus)   │ Opus  │ 96k     │ 48000       │ -f ogg  │ .opus     │ audio/ogg  │ yes        │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Default AAC (M4A)   │ AAC   │ 256k    │ 44100       │ -f mp4  │ .m4a      │ audio/mp4  │ when done  │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Mobile AAC (M4A)    │ AAC   │ 128k    │ 44100       │ -f mp4  │ .m4a      │ audio/mp4  │ when done  │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Default ADTS stream │ AAC   │ 256k    │ 44100       │ -f adts │ .aac      │ audio/aac  │ no         │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Mobile ADTS stream  │ AAC   │ 128k    │ 44100       │ -f adts │ .aac      │ audio/aac  │ no         │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Default Opus (WebM) │ Opus  │ 192k    │ 48000       │ -f webm │ .webm     │ audio/webm │ no         │
  ├─────────────────────┼───────┼─────────┼─────────────┼─────────┼───────────┼────────────┼────────────┤
  │ Mobile Opus (WebM)  │ Opus  │ 96k     │ 48000       │ -f webm │ .webm     │ audio/webm │ no         │
  └─────────────────────┴───────┴─────────┴─────────────┴─────────┴───────────┴────────────┴────────────┘

  ## Ogg Opus presets
  The Ogg presets are the preferred streaming presets. Opus carries its own
  priming and end trimming information, so sequential tracks play gapless in
  every player that supports it (browsers, ExoPlayer and AVPlayer), and the
  Ogg container can be read from front to back, so a file can be played while
  it is still being transcoded.

  They are encoded at a constant bitrate, which makes the size of the result
  known before the transcode starts: every 20ms packet has the same size and
  the Ogg page overhead is fixed. The server can therefore send an honest
  `Content-Length` right away and support range requests on a transcode that
  is still running. The transcode is padded with zero bytes up to the
  predicted size, which Ogg readers ignore. See `predicted_size/2`.

  ## AAC and ADTS presets
  AAC in an M4A container is gapless (ffmpeg writes the edit list and trims
  the last sample) but the container index is written last, so the file can
  only be served once the transcode is done. ADTS can be streamed while
  transcoding but can never be gapless. The WebM presets have no seek index
  when written to a pipe. These presets are kept for clients that were built
  against them, new clients should use the Ogg presets.
  """

  alias Ondu.Files.File
  alias Ondu.Storage
  alias Ondu.Transcoder.Utils

  defstruct [
    :id,
    :ext,
    :bitrate,
    :ffmpeg_preset,
    :mimetype,
    :sample_rate,
    streamable?: true,
    exact_size?: false
  ]

  @type t :: %__MODULE__{
          id: atom(),
          bitrate: non_neg_integer(),
          sample_rate: non_neg_integer(),
          ffmpeg_preset: :ogg | :aac | :adts | :opus,
          streamable?: boolean(),
          exact_size?: boolean(),
          mimetype: String.t(),
          ext: String.t()
        }

  # Opus always uses 20ms packets, so 50 packets (and 50 Ogg lacing entries)
  # per second, and ffmpeg writes a page per second by default.
  @opus_packets_per_second 50
  @ogg_page_header_bytes 27
  # OpusHead and OpusTags pages, with only the encoder vendor string.
  @ogg_header_bytes 1024
  # Padding slack: the pre-skip and encoder flush add a few packets and the
  # duration is a rounded number, two seconds of packets is plenty.
  @ogg_slack_seconds 2

  @spec default_preset :: t()
  def default_preset, do: Enum.find(list(), &(&1.id == :default_ogg))

  @spec list() :: [t()]
  def list do
    [
      %__MODULE__{
        id: :default_ogg,
        bitrate: 192,
        sample_rate: 48_000,
        ffmpeg_preset: :ogg,
        exact_size?: true,
        mimetype: "audio/ogg",
        ext: "opus"
      },
      %__MODULE__{
        id: :mobile_ogg,
        bitrate: 96,
        sample_rate: 48_000,
        ffmpeg_preset: :ogg,
        exact_size?: true,
        mimetype: "audio/ogg",
        ext: "opus"
      },
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

  @spec ids() :: [String.t()]
  def ids, do: Enum.map(list(), &to_string(&1.id))

  @spec get(id :: String.t() | atom()) :: t()
  def get(id) do
    list()
    |> Enum.find(&(to_string(&1.id) == to_string(id)))
    |> case do
      nil -> default_preset()
      preset -> preset
    end
  end

  @doc """
  With `valid_samples:` the decoded audio is cut to that many samples (of the
  source's sample rate) before encoding, see `Ondu.Transcoder.Trim`.
  """
  @spec ffmpeg_args(file :: File.t(), preset :: t(), valid_samples: non_neg_integer() | nil) ::
          [String.t()]
  def ffmpeg_args(%File{} = file, %__MODULE__{} = preset, opts \\ []) do
    uri = Storage.get_uri(file.path)
    args = ["-i", uri] ++ trim_args(opts[:valid_samples]) ++ ffmpeg_shared_args(file, preset)

    if preset.streamable? do
      args
    else
      tmp_output_file = Utils.tmp_file_path(file.id, preset)
      args ++ [tmp_output_file]
    end
  end

  defp trim_args(samples) when is_integer(samples) and samples > 0,
    do: ["-af", "atrim=end_sample=#{samples}"]

  defp trim_args(_samples), do: []

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

  @doc """
  The size of the transcode for presets with an exact size, before it exists.

  For constant bitrate Opus every packet is `bitrate / 400` bytes (20ms worth)
  and each packet costs `ceil(packet / 255)` lacing bytes in the page it is in.
  The result is an upper bound: the real transcode is padded up to it.
  """
  @spec predicted_size(file :: File.t(), preset :: t()) :: non_neg_integer()
  def predicted_size(
        %File{metadata: %{duration: duration}} = file,
        %__MODULE__{
          ffmpeg_preset: :ogg
        } = preset
      )
      when is_number(duration) do
    packet_bytes = div(bitrate(file, preset) * 1000, 400)
    lacing_bytes = ceil(packet_bytes / 255)
    seconds = ceil(duration) + @ogg_slack_seconds
    packets = seconds * @opus_packets_per_second

    packets * (packet_bytes + lacing_bytes) + seconds * @ogg_page_header_bytes +
      @ogg_header_bytes
  end

  defp ffmpeg_shared_args(%File{} = file, %__MODULE__{ffmpeg_preset: :ogg} = preset) do
    bitrate = bitrate(file, preset)
    audio_channels = audio_channels(file, preset)

    # Constant bitrate so the size is predictable, see `predicted_size/2`. No
    # metadata is copied, tags of any size would make the size unpredictable.
    # libopus only encodes at 48000, other rates are resampled by ffmpeg.
    ~w(
        -c:a libopus -b:a #{bitrate}k -vbr off -f ogg -ar 48000 -vn
        -ac #{audio_channels}
        -map_metadata -1
        -y -v quiet -nostats
        pipe:1
      )
  end

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
