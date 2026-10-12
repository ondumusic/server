defmodule Ondu.TestHelpers do
  @moduledoc false

  import ExUnit.Assertions

  @doc """
  Retries `fun` every 10ms until it returns a truthy value, fails after `retries`.
  """
  def assert_eventually(fun, retries \\ 100) do
    if fun.() do
      :ok
    else
      if retries <= 0, do: flunk("assert_eventually timed out")
      :timer.sleep(10)
      assert_eventually(fun, retries - 1)
    end
  end
end
