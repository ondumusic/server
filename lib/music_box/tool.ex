defmodule MusicBox.Tool do
  @moduledoc false
  @callback exec(args :: term()) :: {:ok, term()} | {:error, term()}
end
