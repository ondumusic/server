defmodule Ondu.FractionalIndexTest do
  use ExUnit.Case, async: true

  alias Ondu.FractionalIndex
  alias Ondu.FractionalIndex.Error

  # Test vectors taken verbatim from the canonical Python port's test suite,
  # which is byte-for-byte compatible with the JS rocicorp/fractional-indexing
  # package. Source: httpie/fractional-indexing-python/tests.py
  describe "generate_key_between/2 (base 62)" do
    @ok_cases [
      {nil, nil, "a0"},
      {nil, "a0", "Zz"},
      {nil, "Zz", "Zy"},
      {"a0", nil, "a1"},
      {"a1", nil, "a2"},
      {"a0", "a1", "a0V"},
      {"a1", "a2", "a1V"},
      {"a0V", "a1", "a0l"},
      {"Zz", "a0", "ZzV"},
      {"Zz", "a1", "a0"},
      {nil, "Y00", "Xzzz"},
      {"bzz", nil, "c000"},
      {"a0", "a0V", "a0G"},
      {"a0", "a0G", "a08"},
      {"b125", "b129", "b127"},
      {"a0", "a1V", "a1"},
      {"Zz", "a01", "a0"},
      {nil, "a0V", "a0"},
      {nil, "b999", "b99"},
      {nil, "A000000000000000000000000001", "A000000000000000000000000000V"},
      {"zzzzzzzzzzzzzzzzzzzzzzzzzzy", nil, "zzzzzzzzzzzzzzzzzzzzzzzzzzz"},
      {"zzzzzzzzzzzzzzzzzzzzzzzzzzz", nil, "zzzzzzzzzzzzzzzzzzzzzzzzzzzV"}
    ]

    for {a, b, expected} <- @ok_cases do
      test "between(#{inspect(a)}, #{inspect(b)}) == #{inspect(expected)}" do
        assert FractionalIndex.generate_key_between(unquote(a), unquote(b)) == unquote(expected)
      end
    end

    @error_cases [
      {nil, "A00000000000000000000000000", "invalid order key: A00000000000000000000000000"},
      {"a00", nil, "invalid order key: a00"},
      {"a00", "a1", "invalid order key: a00"},
      {"0", "1", "invalid order key head: 0"},
      {"a1", "a0", "a1 >= a0"}
    ]

    for {a, b, msg} <- @error_cases do
      test "between(#{inspect(a)}, #{inspect(b)}) raises with #{inspect(msg)}" do
        assert_raise Error, unquote(msg), fn ->
          FractionalIndex.generate_key_between(unquote(a), unquote(b))
        end
      end
    end
  end

  describe "generate_n_keys_between/3" do
    test "5 keys between nil and nil (base 10)" do
      assert FractionalIndex.generate_n_keys_between(nil, nil, 5, "0123456789") ==
               ~w(a0 a1 a2 a3 a4)
    end

    test "10 keys after a4 (base 10)" do
      assert FractionalIndex.generate_n_keys_between("a4", nil, 10, "0123456789") ==
               ~w(a5 a6 a7 a8 a9 b00 b01 b02 b03 b04)
    end

    test "5 keys before a0 (base 10)" do
      assert FractionalIndex.generate_n_keys_between(nil, "a0", 5, "0123456789") ==
               ~w(Z5 Z6 Z7 Z8 Z9)
    end

    test "20 keys between a0 and a2 (base 10)" do
      assert FractionalIndex.generate_n_keys_between("a0", "a2", 20, "0123456789") ==
               ~w(a01 a02 a03 a035 a04 a05 a06 a07 a08 a09 a1 a11 a12 a13 a14 a15 a16 a17 a18 a19)
    end

    test "n=0 returns empty list" do
      assert FractionalIndex.generate_n_keys_between(nil, nil, 0) == []
    end
  end

  describe "validate/2" do
    test "accepts valid keys" do
      for key <- ~w(a0 a0V Zz b00 A000000000000000000000000001) do
        assert FractionalIndex.validate(key) == :ok
      end
    end

    test "rejects malformed keys" do
      assert {:error, _} = FractionalIndex.validate("")
      assert {:error, _} = FractionalIndex.validate("zm")
      assert {:error, _} = FractionalIndex.validate("foo")
      assert {:error, _} = FractionalIndex.validate("a00")
      assert {:error, _} = FractionalIndex.validate("A00000000000000000000000000")
    end

    test "rejects keys with characters outside the digit alphabet" do
      # These pass the spec-conformant validator (right structural shape) but
      # contain chars not in base-62, so they would crash midpoint/increment later.
      assert {:error, msg} = FractionalIndex.validate("a#?!@1-9")
      assert msg =~ "alphabet"

      assert {:error, _} = FractionalIndex.validate("a!")
      assert {:error, _} = FractionalIndex.validate("a 1")
      assert {:error, _} = FractionalIndex.validate("a😀")
      # Even structurally-valid-looking keys with one bad char get rejected
      assert {:error, _} = FractionalIndex.validate("b1@")
    end

    test "rejects non-string input" do
      assert {:error, _} = FractionalIndex.validate(nil)
      assert {:error, _} = FractionalIndex.validate(123)
    end

    test "enforces max length" do
      long_key = "a" <> String.duplicate("V", 200)
      assert {:error, msg} = FractionalIndex.validate(long_key, max_length: 50)
      assert msg =~ "max length"

      # Default 100 also rejects
      assert {:error, _} = FractionalIndex.validate(long_key)
    end
  end

  describe "round-trip stability" do
    test "1000 random insertions produce only valid keys, all sorted" do
      :rand.seed(:exsss, {1, 2, 3})
      # Start with a few keys
      seed_keys =
        Enum.reduce(1..5, {nil, []}, fn _, {prev, acc} ->
          k = FractionalIndex.generate_key_between(prev, nil)
          {k, [k | acc]}
        end)
        |> elem(1)
        |> Enum.reverse()

      keys =
        Enum.reduce(1..1000, seed_keys, fn _, list ->
          n = length(list)
          pos = :rand.uniform(n + 1) - 1
          a = if pos > 0, do: Enum.at(list, pos - 1), else: nil
          b = if pos < n, do: Enum.at(list, pos), else: nil
          new_key = FractionalIndex.generate_key_between(a, b)
          List.insert_at(list, pos, new_key)
        end)

      assert keys == Enum.sort(keys)
      assert length(keys) == length(Enum.uniq(keys))
      assert Enum.all?(keys, fn k -> FractionalIndex.validate(k) == :ok end)
    end
  end
end
