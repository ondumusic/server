defmodule MusicBoxWeb.NoticeJSON do
  use MusicBoxWeb, :json

  def notices(%{notices: notices}), do: %{notices: Enum.map(notices, &notice/1)}

  def notice(notice) do
    %{
      id: notice.id,
      code: notice.code,
      level: notice.level,
      message: notice.message,
      raisedAt: notice.raised_at
    }
  end
end
