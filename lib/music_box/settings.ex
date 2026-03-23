defmodule MusicBox.Settings do
  @moduledoc false

  use MusicBox.Schema

  @primary_key false
  schema "settings" do
    field :music_path, :string
    field :is_current, :boolean
    field :scan_type, Ecto.Enum, values: ~w(full quick)a
    field :strip_sort_prefixes, {:array, :string}, default: []

    # The poll interval is in minutes, defaults to 60 minutes (hourly)
    field :poll_interval, :integer, default: 60

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec get() :: t()
  def get do
    case Repo.get_by(Settings, is_current: true) do
      %Settings{} = settings -> settings
      _ -> create_settings!()
    end
  end

  @spec set(map()) :: Repo.result(t())
  def set(attrs), do: set(get(), attrs)

  @spec set(t(), map()) :: Repo.result(t())
  def set(%Settings{} = settings, attrs) do
    settings
    |> cast(attrs, [:music_path, :scan_type, :poll_interval, :strip_sort_prefixes])
    |> validate_number(:poll_interval, greater_than_or_equal_to: 5, less_than_or_equal_to: 1_440)
    |> validate_music_path()
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: {:unsafe_fragment, "(is_current) WHERE is_current"}
    )
    |> tap(fn
      {:ok, new_settings} ->
        if new_settings.strip_sort_prefixes != settings.strip_sort_prefixes do
          MusicBox.Cleanup.work_async(:sort_names)
        end

      {:error, _changeset} ->
        nil
    end)
  end

  defp validate_music_path(changeset) do
    music_path = get_field(changeset, :music_path)

    with {:path, "/" <> _absolute} <- {:path, music_path},
         :ok <- MusicBox.Storage.validate_origin(music_path) do
      changeset
    else
      {:path, _path} ->
        add_error(changeset, :music_path, "should be an absolute path")

      {:error, :enoent} ->
        add_error(changeset, :music_path, "does not exist")

      {:error, :enotdir} ->
        add_error(changeset, :music_path, "is not a directory")

      {:error, :eacces} ->
        add_error(changeset, :music_path, "cannot access directory (check permissions)")

      _ ->
        add_error(changeset, :music_path, "unknown error trying to read directory")
    end
  end

  defp create_settings! do
    %Settings{is_current: true}
    |> change()
    |> Repo.insert!()
  end
end
