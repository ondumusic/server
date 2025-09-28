defmodule MusicBox.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :music_box,
    adapter: Ecto.Adapters.SQLite3

  @paginate_opts [
    repo: __MODULE__,
    max_limit: 100,
    default_limit: 50,
    replace_invalid_params: true
  ]
  def paginate(queryable, params, opts \\ []) when is_map(params) do
    opts = Keyword.merge(@paginate_opts, opts)
    {entries, meta} = Flop.validate_and_run!(queryable, params, opts)

    %{
      entries: entries,
      page_number: meta.current_page,
      page_size: meta.page_size,
      total_entries: meta.total_count,
      total_pages: meta.total_pages
    }
  end
end
