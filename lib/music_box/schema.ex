defmodule MusicBox.Schema do
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.{Changeset, Query}, warn: false

      alias __MODULE__
      alias MusicBox.Repo
    end
  end
end
