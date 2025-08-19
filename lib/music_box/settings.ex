defmodule MusicBox.Settings do
  use MusicBox.Schema

  @primary_key false
  schema "settings" do
    field :music_path, :string
    field :is_current, :boolean
    field :scan_type, Ecto.Enum, values: ~w(full quick)a

    # The poll interval is in minutes, defaults to 60 minutes (hourly)
    field :poll_interval, :integer, default: 60

    timestamps(type: :utc_datetime)
  end

  def get do
    case Repo.get_by(Settings, is_current: true) do
      %Settings{} = settings -> settings
      _ -> create_settings!()
    end
  end

  def set(attrs), do: set(get(), attrs)

  def set(%Settings{} = settings, attrs) do
    settings
    |> cast(attrs, [:music_path, :scan_type, :poll_interval])
    |> validate_number(:poll_interval, greater_than_or_equal_to: 5, less_than_or_equal_to: 1_440)
    |> validate_music_path()
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: {:unsafe_fragment, "(is_current) WHERE is_current"}
    )
  end

  defp validate_music_path(changeset) do
    music_path = get_field(changeset, :music_path)

    with {:path, "/" <> _absolute} <- {:path, music_path},
         true <- File.dir?(music_path),
         {:ok, _} <- File.ls(music_path) do
      changeset
    else
      {:path, _path} ->
        add_error(changeset, :music_path, "should be an absolute path")

      false ->
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
