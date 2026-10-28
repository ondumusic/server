defmodule OnduWeb.Plugs.LocaleTest do
  use ExUnit.Case, async: true

  alias OnduWeb.Plugs.Locale

  @known ["en", "nl", "pt_BR"]

  test "picks the first known language in order of preference" do
    assert Locale.pick_locale("fr, nl;q=0.8, en;q=0.9", @known) == "en"
    assert Locale.pick_locale("nl", @known) == "nl"
  end

  test "matches a region tag exactly and falls back to its language" do
    assert Locale.pick_locale("pt-BR", @known) == "pt_BR"
    assert Locale.pick_locale("pt-BR", ["pt", "pt_BR"]) == "pt_BR"
    assert Locale.pick_locale("pt-PT", @known) == nil
    assert Locale.pick_locale("en-GB", @known) == "en"
  end

  test "ignores case and whitespace" do
    assert Locale.pick_locale(" PT-br ;q=1", @known) == "pt_BR"
  end

  test "returns nil without a known language" do
    assert Locale.pick_locale("", @known) == nil
    assert Locale.pick_locale("fr, de", @known) == nil
    assert Locale.pick_locale("*", @known) == nil
  end
end
