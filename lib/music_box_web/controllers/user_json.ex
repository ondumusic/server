defmodule MusicBoxWeb.UserJSON do
  use MusicBoxWeb, :json

  def changeset(%{changeset: changeset}) do
    %{
      ok: false,
      fields: json_changeset(changeset)
    }
  end
end
