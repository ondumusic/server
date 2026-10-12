defmodule Ondu.Notices do
  @moduledoc false

  import Ecto.Query

  alias Ondu.Notices.Notice
  alias Ondu.Repo

  @notices %{
    library_unavailable: %{
      level: :warning,
      message:
        "No music was found in the music path. It might be unavailable (e.g. an " <>
          "unmounted network share), the library is not scanned until it is available again."
    }
  }

  @doc "Returns active notices that were not dismissed, newest first."
  @spec active() :: [Notice.t()]
  def active do
    from(n in active_query(), where: is_nil(n.dismissed_at), order_by: [desc: n.raised_at])
    |> Repo.all()
  end

  @doc "Raises a notice (idempotent for active notices)."
  @spec raise_notice(atom()) :: Repo.result(Notice.t())
  def raise_notice(code) do
    from(n in active_query(), where: n.code == ^code)
    |> Repo.one()
    |> case do
      %Notice{} = notice ->
        {:ok, notice}

      # Only one notice per code can be active, the database makes sure of that.
      nil ->
        with {:ok, notice} <- insert_notice(code) do
          broadcast()
          {:ok, notice}
        end
    end
  end

  defp insert_notice(code) do
    %{level: level, message: message} = Map.fetch!(@notices, code)
    notice = %Notice{code: code, level: level, message: message}

    Repo.insert(%{notice | raised_at: DateTime.utc_now(:second)})
  end

  @doc "Resolves the active notice with the code."
  @spec resolve_notice(atom()) :: :ok
  def resolve_notice(code) do
    {count, _} =
      from(n in active_query(), where: n.code == ^code)
      |> Repo.update_all(set: [resolved_at: DateTime.utc_now(:second)])

    if count > 0, do: broadcast()
    :ok
  end

  @doc "Dismisses an active notice for all clients."
  @spec dismiss(Ecto.UUID.t()) :: Repo.result(Notice.t()) | {:error, :not_found}
  def dismiss(id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Notice{} = notice <- Repo.one(from(n in active_query(), where: n.id == ^id)),
         changeset = Ecto.Changeset.change(notice, dismissed_at: DateTime.utc_now(:second)),
         {:ok, notice} <- Repo.update(changeset) do
      broadcast()
      {:ok, notice}
    else
      {:error, %Ecto.Changeset{}} = error -> error
      _not_found -> {:error, :not_found}
    end
  end

  defp active_query, do: from(n in Notice, where: is_nil(n.resolved_at))

  defp broadcast, do: OnduWeb.Endpoint.broadcast!("library:sync", "notices", %{})
end
