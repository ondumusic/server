defmodule MusicBox.Cleanup do
  @moduledoc false

  alias __MODULE__.Worker

  @steps ~w(sort_names unused update_album_counts update_fts)a

  def work_async(steps \\ :all) do
    steps
    |> available_steps()
    |> Enum.each(&Worker.exec_async/1)
  end

  def work(steps \\ :all) do
    steps
    |> available_steps()
    |> Enum.each(&Worker.exec/1)
  end

  defp available_steps(steps) do
    steps = List.wrap(steps)

    @steps
    |> Enum.filter(fn step ->
      :all in steps or step in steps
    end)
  end
end
