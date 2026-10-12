defmodule Ondu.NoticesTest do
  use Ondu.DataCase, async: true

  alias Ondu.Notices
  alias Ondu.Notices.Notice

  test "raising a notice again keeps the active notice" do
    assert {:ok, %Notice{level: :warning, message: "No music was found" <> _} = notice} =
             Notices.raise_notice(:library_unavailable)

    assert {:ok, ^notice} = Notices.raise_notice(:library_unavailable)
    assert [^notice] = Notices.active()
  end

  test "a resolved notice is raised as a new notice" do
    {:ok, first} = Notices.raise_notice(:library_unavailable)
    assert :ok = Notices.resolve_notice(:library_unavailable)
    assert Notices.active() == []

    {:ok, second} = Notices.raise_notice(:library_unavailable)
    assert second.id != first.id
    assert Repo.aggregate(Notice, :count) == 2
  end

  test "a dismissed notice stays dismissed while it is active" do
    {:ok, notice} = Notices.raise_notice(:library_unavailable)

    assert {:ok, %Notice{dismissed_at: %DateTime{}}} = Notices.dismiss(notice.id)
    assert {:ok, _notice} = Notices.raise_notice(:library_unavailable)
    assert Notices.active() == []
  end

  test "only active notices can be dismissed" do
    {:ok, notice} = Notices.raise_notice(:library_unavailable)
    Notices.resolve_notice(:library_unavailable)

    assert {:error, :not_found} = Notices.dismiss(notice.id)
    assert {:error, :not_found} = Notices.dismiss(Ecto.UUID.generate())
    assert {:error, :not_found} = Notices.dismiss("not-a-uuid")
  end
end
