defmodule OnduWeb.Plugs.Locale do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      conn
      |> get_req_header("accept-language")
      |> List.first("")
      |> pick_locale(Gettext.known_locales(Ondu.Gettext))

    if locale, do: Gettext.put_locale(Ondu.Gettext, locale)

    conn
  end

  @doc """
  This will try to find the first known locale from the `Accept-Language` header.
  """
  @spec pick_locale(String.t(), [String.t()]) :: String.t() | nil
  def pick_locale(header, known) do
    header
    |> parse_languages()
    |> Enum.find_value(&match_locale(&1, known))
  end

  defp parse_languages(header) do
    header
    |> String.split(",")
    |> Enum.map(&parse_language/1)
    |> Enum.reject(&(&1.tag == ""))
    |> Enum.sort_by(& &1.quality, :desc)
    |> Enum.map(& &1.tag)
  end

  defp parse_language(entry) do
    [tag | params] = entry |> String.trim() |> String.split(";")

    quality =
      Enum.find_value(params, 1.0, fn param ->
        case String.trim(param) do
          "q=" <> value -> parse_quality(value)
          _param -> nil
        end
      end)

    %{tag: String.trim(tag), quality: quality}
  end

  defp parse_quality(value) do
    case Float.parse(value) do
      {quality, _rest} -> quality
      :error -> 0.0
    end
  end

  defp match_locale(tag, known) do
    normalized = tag |> String.replace("-", "_") |> String.downcase()
    language = normalized |> String.split("_") |> List.first()

    exact_match? = Enum.find(known, &(String.downcase(&1) == normalized))
    language_match? = Enum.find(known, &(String.downcase(&1) == language))

    exact_match? || language_match?
  end
end
