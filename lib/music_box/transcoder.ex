defmodule MusicBox.Transcoder do
  use GenServer
  require Logger

  alias MusicBox.Transcoder.{Job, Result, State, Utils}
  alias MusicBox.Files.File

  @chunks_table :transcoder_chunks
  @meta_table :transcoder_meta
  @max_concurrency 3
  @max_cached_files 5
  @cleanup_timer_ms 5_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    if :ets.whereis(@chunks_table) == :undefined,
      do: :ets.new(@chunks_table, [:set, :public, :named_table])

    if :ets.whereis(@meta_table) == :undefined,
      do: :ets.new(@meta_table, [:set, :public, :named_table])

    {:ok, %State{}}
  end

  def get_meta(%File{id: file_id}) do
    case :ets.lookup(@meta_table, file_id) do
      [{^file_id, %{} = meta}] -> meta
      _ -> nil
    end
  end

  def clear_cache do
    :ets.delete_all_objects(@chunks_table)
    :ets.delete_all_objects(@meta_table)
  end

  def request_chunk(file, chunk_index) do
    GenServer.call(__MODULE__, {:request_chunk, file, chunk_index}, 30_000)
  end

  def handle_call({:request_chunk, %File{} = file, chunk_index}, from, state) do
    meta = get_meta(file)
    lookup_key = {file.id, chunk_index}
    chunk_count = if(meta && meta.completed_at, do: meta.chunk_count)

    if not is_nil(chunk_count) and chunk_index > chunk_count do
      {:reply, {:error, :unknown_chunk}, state}
    else
      case :ets.lookup(@chunks_table, lookup_key) do
        [{^lookup_key, chunk_data}] -> {:reply, {:ok, chunk_data}, state}
        [] -> start_or_enqueue(file, chunk_index, from, state)
      end
    end
  end

  # Too many concurrent jobs, queue the request
  defp start_or_enqueue(file, chunk_index, from, %{jobs: jobs} = state)
       when map_size(jobs) >= @max_concurrency,
       do: enqueue_chunk_request(file, chunk_index, from, state)

  # Request already transcoding, queue the request
  defp start_or_enqueue(%File{id: file_id} = file, chunk_index, from, %{jobs: jobs} = state)
       when is_map_key(jobs, file_id),
       do: enqueue_chunk_request(file, chunk_index, from, state)

  # Start a new transcoding job
  defp start_or_enqueue(file, chunk_index, from, state),
    do: start_transcoding(file, chunk_index, from, state)

  defp start_transcoding(%File{} = file, chunk_index, from, state) do
    upsert_meta(file, %{started_at: Utils.timestamp()})

    job = Job.start(file)
    Process.monitor(job.pid)

    new_jobs = Map.put(state.jobs, file.id, job)
    new_state = %{state | jobs: new_jobs}

    enqueue_chunk_request(file, chunk_index, from, new_state)
  end

  defp enqueue_chunk_request(%File{} = file, chunk_index, from, state) do
    lookup_key = {file.id, chunk_index}
    pending_requests = Map.get(state.requests, lookup_key, [])

    new_requests = Map.put(state.requests, lookup_key, [from | pending_requests])
    new_state = %{state | requests: new_requests}

    {:noreply, new_state}
  end

  def handle_info({:chunk, file, chunk_index, data}, state) do
    lookup_key = {file.id, chunk_index}
    :ets.insert(@chunks_table, {lookup_key, data})

    state.requests
    |> Map.get(lookup_key, [])
    |> Enum.each(fn from ->
      GenServer.reply(from, {:ok, data})
    end)

    new_requests = Map.delete(state.requests, lookup_key)
    {:noreply, %{state | requests: new_requests}}
  end

  def handle_info({:transcoding_complete, file, chunk_count}, state) do
    file_size = transcoded_file_size(file)

    upsert_meta(file, %{
      completed_at: Utils.timestamp(),
      file_size: file_size,
      chunk_count: chunk_count
    })

    new_jobs = Map.delete(state.jobs, file.id)
    state = schedule_cleanup(state)

    {:noreply, %{state | jobs: new_jobs}}
  end

  def handle_info({:transcoding_failed, file}, state) do
    upsert_meta(file, %{failed_at: Utils.timestamp()})

    # Notify all pending requests for this file (any chunk)
    state.requests
    |> Enum.filter(fn {{file_id, _}, _requests} -> file_id == file.id end)
    |> Enum.each(fn from ->
      GenServer.reply(from, {:error, :transcoding_failed})
    end)

    # Remove job and pending requests from state
    new_requests = Map.reject(state.requests, fn {{file_id, _}, _} -> file_id == file.id end)
    new_jobs = Map.delete(state.jobs, file.id)
    state = schedule_cleanup(state)

    {:noreply, %{state | jobs: new_jobs, requests: new_requests}}
  end

  def handle_info(:cleanup, state) do
    # Cleanup failed files
    @meta_table
    |> :ets.select([{{:"$1", %{failed_at: :"$2"}}, [{:"/=", :"$2", nil}], [:"$1"]}])
    |> Enum.each(fn file_id ->
      :ets.delete(@meta_table, file_id)
      :ets.select_delete(@chunks_table, [{{{:"$1", :_}, :_}, [{:==, :"$1", file_id}], [true]}])
    end)

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
      |> Enum.each(fn file_id ->
        :ets.delete(@meta_table, file_id)
        :ets.select_delete(@chunks_table, [{{{:"$1", :_}, :_}, [{:==, :"$1", file_id}], [true]}])
      end)
    end

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    active_job = Enum.find(state.jobs, fn {_, job} -> job.pid == pid end)

    if active_job do
      Logger.error("Failed transcoding file: #{active_job.file.id} - Error: #{reason}")
      upsert_meta(active_job.file, %{failed_at: Utils.timestamp()})
      send(self(), {:transcoding_failed, active_job.file})
    end

    {:noreply, schedule_cleanup(state)}
  end

  defp schedule_cleanup(state) do
    if state.cleanup_timer do
      Process.cancel_timer(state.cleanup_timer)
    end

    cleanup_timer = Process.send_after(self(), :cleanup, @cleanup_timer_ms)
    %{state | cleanup_timer: cleanup_timer}
  end

  defp upsert_meta(%File{id: file_id}, params) do
    current =
      case :ets.lookup(@meta_table, file_id) do
        [{^file_id, map}] -> map
        _ -> %Result{}
      end

    new_map = Map.merge(current, params)
    :ets.insert(@meta_table, {file_id, new_map})
  end

  defp transcoded_file_size(%File{id: file_id}) do
    :ets.select(@chunks_table, [
      {{{file_id, :"$1"}, :"$2"}, [], [:"$_"]}
    ])
    |> Enum.reduce(0, fn {_key, data}, acc ->
      acc + byte_size(data)
    end)
  end
end
