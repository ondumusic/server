defmodule Ondu.ReleaseTest do
  use Ondu.DataCase

  import ExUnit.CaptureIO
  import Ondu.AccountsFixtures

  alias Ondu.Accounts
  alias Ondu.Release

  test "reset_password/1 prints the new password of the user" do
    user = user_fixture()
    output = capture_io(fn -> Release.reset_password(user.username) end)

    assert [_, password] = Regex.run(~r/new password of .+ is: (\S+)/, output)
    assert Accounts.get_user_by_username_and_password(user.username, password)
  end
end
