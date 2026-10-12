defmodule OnduWeb.LoginLimiterTest do
  use ExUnit.Case, async: true

  alias OnduWeb.LoginLimiter

  setup context do
    opts = [name: context.test, max_failures: 3, period_ms: Map.get(context, :period_ms, 60_000)]
    start_supervised!({LoginLimiter, opts})
    [limiter: context.test]
  end

  test "refuses logins after too many failures", %{limiter: limiter} do
    for _ <- 1..2, do: LoginLimiter.failed(limiter)
    assert :ok = LoginLimiter.check(limiter)

    LoginLimiter.failed(limiter)
    assert {:error, retry_after} = LoginLimiter.check(limiter)
    assert retry_after in 59..60
  end

  test "a successful login clears the failures", %{limiter: limiter} do
    for _ <- 1..2, do: LoginLimiter.failed(limiter)
    LoginLimiter.succeeded(limiter)
    LoginLimiter.failed(limiter)

    assert :ok = LoginLimiter.check(limiter)
  end

  @tag period_ms: 50
  test "failures expire after the period", %{limiter: limiter} do
    for _ <- 1..3, do: LoginLimiter.failed(limiter)
    assert {:error, 1} = LoginLimiter.check(limiter)

    Process.sleep(60)
    assert :ok = LoginLimiter.check(limiter)
  end
end
