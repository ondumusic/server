defmodule MusicBoxWeb.Helpers.JSON do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      def json_map(assigns, path, assign_key, opts \\ []) do
        unquote(__MODULE__).json_map(__MODULE__, assigns, path, assign_key, opts)
      end

      import unquote(__MODULE__)
    end
  end

  def json_changeset(%Ecto.Changeset{errors: errors}) do
    Enum.reduce(errors, %{}, fn {field, {message, validation}}, result ->
      message =
        if count = validation[:count],
          do: t(message, message, count, validation),
          else: t(message, validation)

      Map.put(result, field, %{message: message})
    end)
  end

  def json_map(module, assigns, path, assign_key, opts) do
    path =
      Enum.map(path, fn
        key when is_atom(key) -> Access.key(key)
        fun when is_function(fun) -> fun
      end)

    include = opts[:include] || []
    as_fun = opts[:as]
    shared_assigns = Map.take(assigns, [:conn, :current_user] ++ include)
    enumerable = get_in(assigns, path) || []

    enumerable
    |> Enum.map(fn item ->
      assigns = Map.put(shared_assigns, assign_key, item)

      if as_fun do
        as_fun.(assigns)
      else
        apply(module, assign_key, [assigns])
      end
    end)
  end

  defp t(message, message, count, validation),
    do: Gettext.dngettext(MusicBoxWeb.Gettext, "errors", message, message, count, validation)

  defp t(message, validation),
    do: Gettext.dgettext(MusicBoxWeb.Gettext, "errors", message, validation)
end
