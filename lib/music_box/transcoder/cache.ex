defmodule MusicBox.Transcoder.Cache do
  @moduledoc false

  alias MusicBox.Transcoder.{Preset, Result}

  @callback get_meta(file_id :: String.t(), preset :: Preset.t()) ::
              {:ok, Result.t()} | {:error, :not_found}

  @type persist_callback :: (-> Enumerable.t())
  @callback persist(file_id :: String.t(), preset :: Preset.t(), callback :: persist_callback()) ::
              :ok | {:error, atom()}

  @callback get_bytes(
              file_id :: String.t(),
              preset :: Preset.t(),
              start_byte :: non_neg_integer(),
              bytes_to_read :: non_neg_integer()
            ) :: iodata()
end
