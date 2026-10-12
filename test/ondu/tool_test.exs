defmodule Ondu.ToolTest do
  use ExUnit.Case, async: true

  import Ondu.TestHelpers

  alias Ondu.Tool

  @moduletag :tmp_dir

  describe "cmd/3" do
    test "returns the output and exit status" do
      assert Tool.cmd("/bin/sh", ["-c", "echo out; exit 3"], timeout: 5_000) == {"out\n", 3}

      assert {output, 0} =
               Tool.cmd("/bin/sh", ["-c", "echo out; echo err >&2"],
                 timeout: 5_000,
                 stderr_to_stdout: true
               )

      assert output =~ "out" and output =~ "err"
    end

    test "kills the process when it times out", %{tmp_dir: tmp_dir} do
      pid_file = Path.join(tmp_dir, "pid")
      script = "echo $$ > #{pid_file}; exec sleep 30"

      assert {:error, :timeout} = Tool.cmd("/bin/sh", ["-c", script], timeout: 200)

      os_pid = pid_file |> File.read!() |> String.trim()

      running? = fn -> match?({_, 0}, System.cmd("/bin/sh", ["-c", "kill -0 #{os_pid} 2>&1"])) end
      assert_eventually(fn -> not running?.() end)
      refute_received {_port, _message}
    end
  end
end
