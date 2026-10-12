defmodule Ondu.Schema do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.{Changeset, Query}, warn: false

      alias __MODULE__
      alias Ondu.Repo
    end
  end
end
