defmodule MusicBox do
  @moduledoc """
  MusicBox keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @spec env() :: :dev | :test | :prod
  def env, do: Application.get_env(:music_box, :env)
end
