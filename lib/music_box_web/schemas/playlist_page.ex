defmodule MusicBoxWeb.Schemas.PlaylistPage do
  require OpenApiSpex
  alias MusicBoxWeb.Schemas.{Page, Playlist}

  OpenApiSpex.schema(Page.of(Playlist, __subtype: "playlist", title: "PlaylistPage"))
end
