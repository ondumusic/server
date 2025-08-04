defmodule MusicBox.Repo do
  use Ecto.Repo,
    otp_app: :music_box,
    adapter: Ecto.Adapters.SQLite3

  @paginate_opts [
    repo: __MODULE__,
    page_size: 25,
    max_page_size: 25,
    replace_invalid_params: true
  ]
  def paginate(queryable, params) when is_map(params) do
    {entries, meta} = Flop.validate_and_run!(queryable, params, @paginate_opts)

    %{
      entries: entries,
      page_number: meta.current_page,
      page_size: meta.page_size,
      total_entries: meta.total_count,
      total_pages: meta.total_pages
    }
  end
end
