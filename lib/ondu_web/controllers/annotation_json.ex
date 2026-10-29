defmodule OnduWeb.AnnotationJSON do
  use OnduWeb, :json

  def annotations(%{page: page} = assigns) do
    %{
      __type: "page",
      __subtype: "annotation",
      pageNumber: page.page_number,
      pageSize: page.page_size,
      totalEntries: page.total_entries,
      totalPages: page.total_pages,
      entries: json_map(assigns, [:page, :entries], :annotation)
    }
  end

  def annotation(%{annotation: annotation}) do
    %{
      entityId: annotation.entity_id,
      data: annotation.data,
      updatedAt: json_datetime(annotation.updated_at)
    }
  end

  def result(%{skipped: skipped}), do: %{ok: true, skipped: skipped}
end
