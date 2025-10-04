defmodule MusicBox.Transcoder do
  @moduledoc false

  use GenServer
  require Logger

  alias MusicBox.Files.File
  alias MusicBox.Transcoder.{Job, Result, State, Utils}

  @chunks_table :transcoder_chunks
  @meta_table :transcoder_meta
  @max_concurrency 3
  @max_cached_files 5
  @cleanup_timer_ms 5_000

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    if :ets.whereis(@chunks_table) == :undefined,
      do: :ets.new(@chunks_table, [:set, :public, :named_table])

    if :ets.whereis(@meta_table) == :undefined,
      do: :ets.new(@meta_table, [:set, :public, :named_table])

    {:ok, %State{}}
  end

  @spec get_meta(File.t(), atom()) :: Result.t() | nil
  def get_meta(%File{id: file_id}, preset) do
    lookup_key = {file_id, preset}

    path = cache_file_path(file_id, preset)
    persisted? = Elixir.File.exists?(path)

    if persisted? do
      stat = Elixir.File.stat!(path, time: :posix)

      %Result{
        completed_at: DateTime.from_unix(stat.ctime),
        file_size: stat.size,
        chunk_count: ceil(stat.size / Utils.chunk_size()),
        persisted: true
      }
    else
      case :ets.lookup(@meta_table, lookup_key) do
        [{^lookup_key, %{} = meta}] -> meta
        _ -> nil
      end
    end
  end

  @spec clear_cache() :: :ok
  def clear_cache do
    :ets.delete_all_objects(@chunks_table)
    :ets.delete_all_objects(@meta_table)
    :ok
  end

  @type chunk_error :: :unknown_chunk | :transcoding_failed | :no_longer_available
  @spec request_chunk(File.t(), atom(), non_neg_integer()) ::
          {:ok, binary()} | {:error, chunk_error()}
  def request_chunk(file, preset, chunk_index) do
    GenServer.call(__MODULE__, {:request_chunk, file, preset, chunk_index}, 10_000)
  end

  @impl true
  def handle_call({:request_chunk, %File{} = file, preset, chunk_index}, from, state) do
    meta = get_meta(file, preset) || %Result{}
    lookup_key = {file.id, preset, chunk_index}
    completed? = not is_nil(Map.get(meta, :completed_at))
    persisted? = Map.get(meta, :persisted, false)
    chunk_count = if(completed?, do: meta.chunk_count)
    path = cache_file_path(file.id, preset)

    if not is_nil(chunk_count) and chunk_index > chunk_count do
      throw({:unknown_chunk, state})
    end

    if persisted? do
      start_byte = chunk_index * Utils.chunk_size()
      end_byte = min(meta.file_size, start_byte + Utils.chunk_size())
      bytes_to_read = max(0, end_byte - start_byte)
      chunk_data = read_file_bytes(path, start_byte, bytes_to_read)

      if chunk_data do
        {:reply, {:ok, chunk_data}, state}
      else
        throw({:unknown_chunk, state})
      end
    else
      case :ets.lookup(@chunks_table, lookup_key) do
        [{^lookup_key, chunk_data}] -> {:reply, {:ok, chunk_data}, state}
        [] -> start_or_enqueue(file, preset, chunk_index, from, state)
      end
    end
  catch
    {:unknown_chunk, state} -> {:reply, {:error, :unknown_chunk}, state}
    error -> error
  end

  # Too many concurrent jobs, queue the request
  defp start_or_enqueue(_file, _preset, _chunk_index, _from, %{jobs: jobs} = _state)
       when map_size(jobs) >= @max_concurrency,
       do: raise("TODO: Not Implemented Yet")

  # Request already transcoding, queue the request
  defp start_or_enqueue(
         %File{id: file_id} = file,
         preset,
         chunk_index,
         from,
         %{jobs: jobs} = state
       )
       when is_map_key(jobs, {file_id, preset}),
       do: enqueue_chunk_request(file, preset, chunk_index, from, state)

  # Start a new transcoding job
  defp start_or_enqueue(file, preset, chunk_index, from, state),
    do: start_transcoding(file, preset, chunk_index, from, state)

  defp start_transcoding(%File{} = file, preset, chunk_index, from, state) do
    job = Job.start(file, preset)
    upsert_meta(job, %{started_at: Utils.timestamp()})
    Process.monitor(job.pid)

    new_jobs = Map.put(state.jobs, {file.id, preset}, job)
    new_state = %{state | jobs: new_jobs}

    enqueue_chunk_request(file, preset, chunk_index, from, new_state)
  end

  defp enqueue_chunk_request(%File{} = file, preset, chunk_index, from, state) do
    lookup_key = {file.id, preset, chunk_index}
    pending_requests = Map.get(state.requests, lookup_key, [])

    new_requests = Map.put(state.requests, lookup_key, [from | pending_requests])
    new_state = %{state | requests: new_requests}

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:chunk, %Job{} = job, chunk_index, data}, state) do
    %{file: file, preset: preset} = job
    lookup_key = {file.id, preset, chunk_index}
    :ets.insert(@chunks_table, {lookup_key, data})

    state.requests
    |> Map.get(lookup_key, [])
    |> send_reply({:ok, data})

    new_requests = Map.delete(state.requests, lookup_key)
    {:noreply, %{state | requests: new_requests}}
  end

  def handle_info({:transcoding_complete, %Job{} = job, chunk_count}, state) do
    %{file: file, preset: preset} = job
    file_size = transcoded_file_size(job)

    upsert_meta(job, %{
      completed_at: Utils.timestamp(),
      file_size: file_size,
      chunk_count: chunk_count
    })

    # If there are still pending requests we should deal with them
    state.requests
    |> Enum.filter(fn
      {{file_id, ^preset, chunk_index}, _requests} ->
        file_id == file.id and chunk_index >= chunk_count

      _ ->
        false
    end)
    |> Enum.each(fn {lookup_key, requests} ->
      case :ets.lookup(@chunks_table, lookup_key) do
        # The chunk should exist, unless it was already cleaned up?
        [{^lookup_key, chunk_data}] -> send_reply(requests, {:ok, chunk_data})
        [] -> send_reply(requests, {:error, :no_longer_available})
      end
    end)

    # Persist cache
    persist_cache(job)

    {:noreply, cleanup_job(state, job)}
  end

  def handle_info({:transcoding_failed, %Job{} = job}, state) do
    %{file: file} = job
    upsert_meta(job, %{failed_at: Utils.timestamp()})

    # Notify all pending requests for this file (any chunk)
    state.requests
    |> Enum.filter(fn {{file_id, _, _}, _requests} -> file_id == file.id end)
    |> Enum.flat_map(fn {_, requests} -> requests end)
    |> send_reply({:error, :transcoding_failed})

    {:noreply, cleanup_job(state, job)}
  end

  def handle_info(:cleanup, state) do
    # Cleanup failed files
    @meta_table
    |> :ets.select([{{:"$1", %{failed_at: :"$2"}}, [{:"/=", :"$2", nil}], [:"$1"]}])
    |> Enum.each(&cleanup_lookup_key/1)

    # Find the oldest valid timestamp (most X recent)
    cutoff_timestamp =
      @meta_table
      |> :ets.select([
        {{:_, %{__struct__: Result, started_at: :"$1"}}, [], [:"$1"]}
      ])
      |> Enum.sort(:desc)
      |> Enum.at(@max_cached_files - 1)

    # If needed, delete all files/chunks older than the top X
    if cutoff_timestamp do
      @meta_table
      |> :ets.select([
        {{:"$1", %{__struct__: Result, started_at: :"$2"}}, [{:<, :"$2", cutoff_timestamp}],
         [:"$1"]}
      ])
      |> Enum.each(&cleanup_lookup_key/1)
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case Enum.find(state.jobs, fn {_, job} -> job.pid == pid end) do
      {{_file_id, _preset}, active_job} ->
        Logger.error("Failed transcoding file: #{active_job.file.id} - Error: #{inspect(reason)}")
        upsert_meta(active_job, %{failed_at: Utils.timestamp()})
        send(self(), {:transcoding_failed, active_job.file})

      nil ->
        :noop
    end

    {:noreply, schedule_cleanup(state)}
  end

  defp send_reply(requests, reply) do
    Enum.each(requests, fn from ->
      GenServer.reply(from, reply)
    end)
  end

  defp read_file_bytes(path, start_byte, bytes_to_read) do
    case Elixir.File.open(path, [:binary, :read]) do
      {:ok, file} ->
        :file.position(file, start_byte)
        chunk_data = IO.binread(file, bytes_to_read)
        Elixir.File.close(file)
        chunk_data

      _ ->
        nil
    end
  end

  defp cleanup_lookup_key(lookup_key) do
    {file_id, preset} = lookup_key
    :ets.delete(@meta_table, lookup_key)

    :ets.select_delete(@chunks_table, [
      {
        {{:"$1", :"$2", :_}, :_},
        [
          {:==, :"$1", file_id},
          {:==, :"$2", preset}
        ],
        [true]
      }
    ])
  end

  defp cleanup_job(state, job) do
    %{file: file, preset: preset} = job

    new_requests =
      Map.reject(state.requests, fn
        {{file_id, ^preset, _}, _} -> file_id == file.id
        _ -> false
      end)

    new_jobs = Map.delete(state.jobs, {file.id, preset})
    state = schedule_cleanup(state)

    %{state | jobs: new_jobs, requests: new_requests}
  end

  defp schedule_cleanup(state) do
    if state.cleanup_timer do
      Process.cancel_timer(state.cleanup_timer)
    end

    cleanup_timer = Process.send_after(self(), :cleanup, @cleanup_timer_ms)
    %{state | cleanup_timer: cleanup_timer}
  end

  defp upsert_meta(%Job{file: %File{} = file, preset: preset}, params) do
    lookup_key = {file.id, preset}
    current = get_meta(file, preset) || %Result{}
    new_map = Map.merge(current, params)
    :ets.insert(@meta_table, {lookup_key, new_map})
  end

  defp transcoded_file_size(%Job{file: %File{id: file_id}, preset: preset}) do
    :ets.select(@chunks_table, [
      {{{file_id, preset, :"$1"}, :"$2"}, [], [:"$_"]}
    ])
    |> Enum.reduce(0, fn {_key, data}, acc ->
      acc + byte_size(data)
    end)
  end

  defp persist_cache(job) do
    %{file: %{id: file_id}, preset: preset} = job
    path = cache_file_path(file_id, preset)
    Elixir.File.mkdir_p!(Path.dirname(path))

    case Elixir.File.open(path, [:write, :binary, :exclusive]) do
      {:ok, file} ->
        :ets.select(@chunks_table, [
          {{{file_id, preset, :"$1"}, :"$2"}, [], [:"$_"]}
        ])
        |> Enum.sort_by(fn {{_, _, n}, _} -> n end)
        |> Enum.each(fn {_key, data} ->
          :ok = IO.binwrite(file, data)
        end)

        Elixir.File.close(file)

      _ ->
        :ok
    end
  end

  defp cache_file_path(file_id, preset) do
    filename = "#{file_id}-#{preset}.webm"
    Path.join(config(:cache_path), filename)
  end

  defp config(key),
    do: Application.get_env(:music_box, MusicBox.Transcoder) |> Keyword.get(key)
end
