defmodule MusicBox.FileScanner.Pipeline do
  use Broadway
  alias Broadway.Message
  alias MusicBox.FileScanner.{Analyzer, Entry, Operations, Utils}

  def start_link(opts) do
    auto_start = Keyword.get(opts, :auto_start, true)

    producer_module =
      Application.fetch_env!(:music_box, MusicBox.FileScanner)
      |> Keyword.fetch!(:producer_module)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {producer_module, auto_start: auto_start},
        concurrency: 1,
        transformer: {__MODULE__, :transform, []}
      ],
      processors: [
        default: [concurrency: 5]
      ],
      batchers: [
        default: [concurrency: 5, batch_size: 20]
      ]
    )
  end

  def transform(entry, _opts) do
    %Message{
      data: entry,
      acknowledger: {__MODULE__, :default, :ack_data}
    }
  end

  @impl true
  def prepare_messages(messages, _context) do
    # If the scan type is quick we can ignore any existing files.
    found_paths =
      messages
      |> Enum.filter(&(&1.data.scan_type == :quick))
      |> Enum.reject(& &1.data.is_dir)
      |> Enum.map(& &1.data.path)
      |> Operations.filter_existing_paths()

    messages
    |> Enum.map(fn %Message{data: %Entry{path: path}} = message ->
      if path in found_paths do
        Message.failed(message, :is_exists)
      else
        message
      end
    end)
  end

  @impl true
  def handle_message(_processor, %Message{data: %Entry{is_dir: true}} = message, _context),
    do: Message.failed(message, :is_directory)

  def handle_message(_processor, %Message{status: :ok} = message, _context) do
    with {:ok, type} <- Utils.detect_file_type(message.data.path),
         {:ok, result} <- Analyzer.analyze(message.data, type: type) do
      Message.put_data(message, result)
    else
      _ -> Message.failed(message, :is_unknown)
    end
  end

  def handle_message(_processor, message, _context),
    do: message

  @impl true
  def handle_batch(:default, messages, _batch_info, _context),
    do: messages

  def ack(:default, successful, failed) do
    # only music files should have been successful, so next step is
    # batch inserting them into the database.
    successful
    |> Enum.map(& &1.data)
    |> Operations.batch_insert()

    # Send directory entries back to a random producer to walk them and find
    # even more files and/or directories.
    failed
    |> Enum.filter(&(&1.status == {:failed, :is_directory}))
    |> Enum.map(& &1.data)
    |> Operations.walk_entries(__MODULE__)
  end
end
