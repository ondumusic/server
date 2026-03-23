defmodule MusicBox.Repo.Migrations.UseRelativeFilePaths do
  use Ecto.Migration

  def up do
    prefix =
      repo().query!("select music_path from settings limit 1")
      |> then(fn %{rows: rows} ->
        case rows do
          [[val]] when is_binary(val) and val != "" -> val
          _ -> nil
        end
      end)

    if prefix do
      # Prefix can contain trailing / or not, let's make it consistent
      # so our +2 on the length in the update query is always accurate.
      prefix = String.trim_trailing(prefix, "/")

      # Strip the prefix from all file paths that start with it
      # Uses length+1 to skip past the prefix, keeping the rest of the path
      prefix_len = String.length(prefix)

      repo().query!(
        "update files set path = substr(path, ?1) where path like ?2",
        [prefix_len + 2, "#{prefix}%"]
      )
    end
  end
end
