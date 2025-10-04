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

  @type result(mod) :: {:ok, mod} | {:error, Ecto.Changeset.t()}

  @type page(entry_type) :: %{
          entries: [entry_type],
          page_number: non_neg_integer(),
          page_size: non_neg_integer(),
          total_entries: non_neg_integer(),
          total_pages: non_neg_integer()
        }

  @type paginate_opts ::
          {:repo, atom()}
          | {:max_limit, non_neg_integer()}
          | {:default_limit, non_neg_integer()}
          | {:replace_invalid_params, boolean()}
  @spec paginate(Ecto.Queryable.t(), map(), [paginate_opts()]) :: page(Ecto.Schema.t())
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
