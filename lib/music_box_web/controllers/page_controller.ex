defmodule MusicBoxWeb.PageController do
  use MusicBoxWeb, :controller

  alias MusicBox.Accounts

  def react(conn, _params) do
    has_user? = Accounts.has_user?()
    # has_settings? = false

    onboarding_step = nil

    onboarding_step =
      if not has_user? and is_nil(onboarding_step),
        do: "user",
        else: onboarding_step

    # onboarding_step =
    #   if not has_settings? and is_nil(onboarding_step),
    #     do: "settings",
    #     else: onboarding_step

    hydrate = %{
      onboarding: onboarding_step
    }

    http_status =
      if is_nil(onboarding_step),
        do: :ok,
        else: :failed_dependency

    conn
    |> put_status(http_status)
    |> render(:react, hydrate: hydrate)
  end
end
