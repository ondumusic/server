ExUnit.start(exclude: [:skip], assert_receive_timeout: 1_500, max_cases: 4)
Ecto.Adapters.SQL.Sandbox.mode(MusicBox.Repo, :manual)
