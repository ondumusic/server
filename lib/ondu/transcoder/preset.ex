defmodule Ondu.Transcoder.Preset do
  @moduledoc """
  The transcoding presets and the ffmpeg arguments that produce them.

  ┌─────────────┬───────┬─────────┬─────────────┬────────┬───────────┬───────────┐
  │   Preset    │ Codec │ Bitrate │ Sample Rate │ Format │ Extension │   MIME    │
  ├─────────────┼───────┼─────────┼─────────────┼────────┼───────────┼───────────┤
  │ default_ogg │ Opus  │ 192k    │ 48000       │ -f ogg │ .opus     │ audio/ogg │
  ├─────────────┼───────┼─────────┼─────────────┼────────┼───────────┼───────────┤
  │ mobile_ogg  │ Opus  │ 96k     │ 48000       │ -f ogg │ .opus     │ audio/ogg │
  └─────────────┴───────┴─────────┴─────────────┴────────┴───────────┴───────────┘

  Opus carries its own priming and end trimming information, so sequential
  tracks play gapless in every player that supports it (browsers, ExoPlayer
  and AVPlayer), and the Ogg container can be read from front to back, so a
  file can be played while it is still being transcoded.

  They are encoded at a constant bitrate, which makes the size of the result
  known before the transcode starts: every 20ms packet has the same size and
  the Ogg page overhead is fixed. The server can therefore send an honest
  `Content-Length` right away and support range requests on a transcode that
  is still running. The transcode is padded up to the predicted size with
  empty Ogg pages, which readers skip. See `predicted_size/2`.
  """

  alias Ondu.Files.File
  alias Ondu.Storage

  defstruct [:id, :ext, :bitrate, :mimetype]

  @type t :: %__MODULE__{
          id: atom(),
          bitrate: non_neg_integer(),
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
      %__MODULE__{id: :default_ogg, bitrate: 192, mimetype: "audio/ogg", ext: "opus"},
      %__MODULE__{id: :mobile_ogg, bitrate: 96, mimetype: "audio/ogg", ext: "opus"}
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
    bitrate = bitrate(file, preset)
    audio_channels = audio_channels(file, preset)

    # Constant bitrate so the size is predictable, see `predicted_size/2`. No
    # metadata is copied, tags of any size would make the size unpredictable.
    # libopus only encodes at 48000, other rates are resampled by ffmpeg.
    ["-i", Storage.get_uri(file.path)] ++
      trim_args(opts[:valid_samples]) ++
      ~w(
        -c:a libopus -b:a #{bitrate}k -vbr off -f ogg -ar 48000 -vn
        -ac #{audio_channels}
        -map_metadata -1
        -y -v quiet -nostats
        pipe:1
      )
  end

  defp trim_args(samples) when is_integer(samples) and samples > 0,
    do: ["-af", "atrim=end_sample=#{samples}"]

  defp trim_args(_samples), do: []

  @spec bitrate(file :: File.t(), preset :: t()) :: non_neg_integer()
  def bitrate(%{metadata: %{bitrate: bitrate}}, preset) when is_integer(bitrate),
    do: min(bitrate, preset.bitrate)

  def bitrate(_file, %{bitrate: bitrate}),
    do: bitrate

  @spec audio_channels(file :: File.t(), preset :: t()) :: non_neg_integer()
  def audio_channels(%{metadata: %{audio_channels: audio_channels}}, _preset)
      when is_integer(audio_channels),
      do: min(2, audio_channels)

  def audio_channels(_file, _preset),
    do: 2

  @doc """
  The size of the transcode, before it exists.

  For constant bitrate Opus every packet is `bitrate / 400` bytes (20ms worth)
  and each packet costs `ceil(packet / 255)` lacing bytes in the page it is in.
  The result is an upper bound: the real transcode is padded up to it.
  """
  @spec predicted_size(file :: File.t(), preset :: t()) :: non_neg_integer()
  def predicted_size(%File{metadata: %{duration: duration}} = file, %__MODULE__{} = preset)
      when is_number(duration) do
    packet_bytes = div(bitrate(file, preset) * 1000, 400)
    lacing_bytes = ceil(packet_bytes / 255)
    seconds = ceil(duration) + @ogg_slack_seconds
    packets = seconds * @opus_packets_per_second

    packets * (packet_bytes + lacing_bytes) + seconds * @ogg_page_header_bytes +
      @ogg_header_bytes
  end
end
