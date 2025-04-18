# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("../test_helper.exs", __DIR__)

defmodule Code.Formatter.GeneralTest do
  use ExUnit.Case, async: true

  import CodeFormatterHelpers

  @short_length [line_length: 10]

  test "does not emit warnings" do
    assert_format "fn -> end", "fn -> nil end"
  end

  describe "unicode normalization" do
    test "with nfc normalizations" do
      assert_format "ç", "ç"
    end

    test "with custom normalizations" do
      assert_format "µs", "μs"
    end
  end

  describe "aliases" do
    test "with atom-only parts" do
      assert_same "Elixir"
      assert_same "Elixir.Foo"
      assert_same "Foo.Bar.Baz"
    end

    test "removes spaces between aliases" do
      assert_format "Foo . Bar . Baz", "Foo.Bar.Baz"
    end

    test "starting with expression" do
      assert_same "__MODULE__.Foo.Bar"
      # Syntactically valid, semantically invalid
      assert_same ~S[~c"Foo".Bar.Baz]
    end

    test "wraps the head in parens if it has an operator" do
      assert_format "+(Foo . Bar . Baz)", "+Foo.Bar.Baz"
      assert_format "(+Foo) . Bar . Baz", "(+Foo).Bar.Baz"
    end
  end

  describe "sigils" do
    test "without interpolation" do
      assert_same ~S[~s(foo)]
      assert_same ~S[~s{foo bar}]
      assert_same ~S[~r/Bar Baz/]
      assert_same ~S[~w<>]
      assert_same ~S[~W()]
      assert_same ~S[~MAT()]
      assert_same ~S[~MAT{1,2,3}]
    end

    test "with escapes" do
      assert_same ~S[~s(foo \) bar)]
      assert_same ~S[~s(f\a\b\ro)]

      assert_same ~S"""
      ~S(foo\
      bar)
      """
    end

    test "with nested new lines" do
      assert_same ~S"""
      foo do
        ~S(foo\
      bar)
      end
      """

      assert_same ~S"""
      foo do
        ~s(#{bar}
      )
      end
      """
    end

    test "with interpolation" do
      assert_same ~S[~s(one #{2} three)]
    end

    test "with modifiers" do
      assert_same ~S[~w(one two three)a]
      assert_same ~S[~z(one two three)foo]
    end

    test "with interpolation on line limit" do
      assert_same ~S"""
                  ~s(one #{"two"} three)
                  """,
                  @short_length
    end

    test "with heredoc syntax" do
      assert_same ~S"""
      ~s'''
      one\a
      #{:two}\r
      three\0
      '''
      """

      assert_same ~S'''
      ~s"""
      one\a
      #{:two}\r
      three\0
      """
      '''
    end

    test "with heredoc syntax and modifier" do
      assert_same ~S"""
      ~s'''
      foo
      '''rsa
      """
    end

    test "with heredoc syntax and interpolation on line limit" do
      assert_same ~S"""
                  ~s'''
                  one #{"two two"} three
                  '''
                  """,
                  @short_length
    end

    test "with custom formatting" do
      bad = """
      ~W/foo  bar  baz/
      """

      good = """
      ~W/foo bar baz/
      """

      formatter = fn content, opts ->
        assert opts == [file: nil, line: 1, sigil: :W, modifiers: [], opening_delimiter: "/"]
        content |> String.split(~r/ +/) |> Enum.join(" ")
      end

      assert_format bad, good, sigils: [W: formatter]

      bad = """
      var = ~W<foo  bar  baz>abc
      """

      good = """
      var = ~W<foo bar baz>abc
      """

      formatter = fn content, opts ->
        assert opts == [file: nil, line: 1, sigil: :W, modifiers: ~c"abc", opening_delimiter: "<"]
        content |> String.split(~r/ +/) |> Enum.intersperse(" ")
      end

      assert_format bad, good, sigils: [W: formatter]

      bad = """
      var = ~MAT{foo  bar  baz}abc
      """

      good = """
      var = ~MAT{foo bar baz}abc
      """

      formatter = fn content, opts ->
        assert opts == [
                 file: nil,
                 line: 1,
                 sigil: :MAT,
                 modifiers: ~c"abc",
                 opening_delimiter: "{"
               ]

        content |> String.split(~r/ +/) |> Enum.intersperse(" ")
      end

      assert_format bad, good, sigils: [MAT: formatter]
    end

    test "with custom formatting on heredocs" do
      bad = """
      ~W'''
      foo  bar  baz
      '''
      """

      good = """
      ~W'''
      foo bar baz
      '''
      """

      formatter = fn content, opts ->
        assert opts == [file: nil, line: 1, sigil: :W, modifiers: [], opening_delimiter: "'''"]
        content |> String.split(~r/ +/) |> Enum.join(" ")
      end

      assert_format bad, good, sigils: [W: formatter]

      bad = ~S'''
      if true do
        ~W"""
        foo
        bar
        baz
        """abc
      end
      '''

      good = ~S'''
      if true do
        ~W"""
        foo
        bar
        baz
        """abc
      end
      '''

      formatter = fn content, opts ->
        assert opts == [
                 file: nil,
                 line: 2,
                 sigil: :W,
                 modifiers: ~c"abc",
                 opening_delimiter: ~S/"""/
               ]

        content |> String.split(~r/ +/) |> Enum.join("\n")
      end

      assert_format bad, good, sigils: [W: formatter]
    end
  end

  describe "anonymous functions" do
    test "with a single clause and no arguments" do
      assert_format "fn  ->:ok  end", "fn -> :ok end"

      bad = "fn -> :foo end"

      good = """
      fn ->
        :foo
      end
      """

      assert_format bad, good, @short_length

      assert_same "fn () when node() == :nonode@nohost -> true end"
    end

    test "with a single clause and arguments" do
      assert_format "fn  x ,y-> x + y  end", "fn x, y -> x + y end"

      bad = "fn x -> foo(x) end"

      good = """
      fn x ->
        foo(x)
      end
      """

      assert_format bad, good, @short_length

      bad = "fn one, two, three -> foo(x) end"

      good = """
      fn one,
         two,
         three ->
        foo(x)
      end
      """

      assert_format bad, good, @short_length
    end

    test "with a single clause and when" do
      code = """
      fn arg
         when guard ->
        :ok
      end
      """

      assert_same code, @short_length
    end

    test "keeps parens if argument includes keyword list" do
      assert_same """
      fn [] when is_integer(x) ->
        x + 42
      end
      """

      bad = """
      fn (input: x) when is_integer(x) ->
        x + 42
      end
      """

      good = """
      fn [input: x] when is_integer(x) ->
        x + 42
      end
      """

      assert_format bad, good
    end

    test "with a single clause, followed by a newline, and can fit in one line" do
      assert_same """
      fn
        hello -> world
      end
      """
    end

    test "with a single clause, followed by a newline, and can not fit in one line" do
      assert_same """
      SomeModule.long_function_name_that_approaches_max_columns(argument, acc, fn
        %SomeStruct{key: key}, acc -> more_code(key, acc)
      end)
      """
    end

    test "with multiple clauses" do
      code = """
      fn
        1 -> :ok
        2 -> :ok
      end
      """

      assert_same code, @short_length

      code = """
      fn
        1 ->
          :ok

        2 ->
          :error
      end
      """

      assert_same code, @short_length

      code = """
      fn
        arg11,
        arg12 ->
          body1

        arg21,
        arg22 ->
          body2
      end
      """

      assert_same code, @short_length

      code = """
      fn
        arg11,
        arg12 ->
          body1

        arg21,
        arg22 ->
          body2

        arg31,
        arg32 ->
          body3
      end
      """

      assert_same code, @short_length
    end

    test "with heredocs" do
      assert_same ~S'''
      fn
        arg1 ->
          """
          foo
          """

        arg2 ->
          """
          bar
          """
      end
      '''
    end

    test "with multiple empty clauses" do
      assert_same """
      fn
        () -> :ok1
        () -> :ok2
      end
      """
    end

    test "with when in clauses" do
      assert_same """
      fn
        a1 when a + b -> :ok
        b1 when c + d -> :ok
      end
      """

      long = """
      fn
        a1, a2 when a + b -> :ok
        b1, b2 when c + d -> :ok
      end
      """

      assert_same long

      good = """
      fn
        a1, a2
        when a +
               b ->
          :ok

        b1, b2
        when c +
               d ->
          :ok
      end
      """

      assert_format long, good, @short_length
    end

    test "uses block context for the body of each clause" do
      assert_same "fn -> @foo bar end"
    end

    test "preserves user choice even when it fits" do
      assert_same """
      fn
        1 ->
          :ok

        2 ->
          :ok
      end
      """

      assert_same """
      fn
        1 ->
          :ok

        2 ->
          :ok

        3 ->
          :ok
      end
      """
    end

    test "with -> on line limit" do
      bad = """
      fn ab, cd ->
        ab + cd
      end
      """

      good = """
      fn ab,
         cd ->
        ab + cd
      end
      """

      assert_format bad, good, @short_length

      bad = """
      fn
        ab, cd ->
          1
        xy, zw ->
          2
      end
      """

      good = """
      fn
        ab,
        cd ->
          1

        xy,
        zw ->
          2
      end
      """

      assert_format bad, good, @short_length
    end
  end

  describe "anonymous functions types" do
    test "with a single clause and no arguments" do
      assert_same "(-> :ok)"
      assert_format "(->:ok)", "(-> :ok)"
      assert_format "( -> :ok)", "(-> :ok)"
      assert_format "(() -> :really_long_atom)", "(-> :really_long_atom)", @short_length
      assert_same "(() when node() == :nonode@nohost -> true)"
    end

    test "with a single clause and arguments" do
      assert_format "( x ,y-> x + y  )", "(x, y -> x + y)"

      bad = "(x -> :really_long_atom)"

      good = """
      (x ->
         :really_long_atom)
      """

      assert_format bad, good, @short_length

      bad = "(one, two, three -> foo(x))"

      good = """
      (one,
       two,
       three ->
         foo(x))
      """

      assert_format bad, good, @short_length
    end

    test "with multiple clauses" do
      code = """
      (
        1 -> :ok
        2 -> :ok
      )
      """

      assert_same code, @short_length

      code = """
      (
        1 ->
          :ok

        2 ->
          :error
      )
      """

      assert_same code, @short_length

      code = """
      (
        arg11,
        arg12 ->
          body1

        arg21,
        arg22 ->
          body2
      )
      """

      assert_same code, @short_length

      code = """
      (
        arg11,
        arg12 ->
          body1

        arg21,
        arg22 ->
          body2

        arg31,
        arg32 ->
          body2
      )
      """

      assert_same code, @short_length
    end

    test "with heredocs" do
      assert_same ~S'''
      (
        arg1 ->
          """
          foo
          """

        arg2 ->
          """
          bar
          """
      )
      '''
    end

    test "with multiple empty clauses" do
      assert_same """
      (
        () -> :ok1
        () -> :ok2
      )
      """
    end

    test "preserves user choice even when it fits" do
      assert_same """
      (
        1 ->
          :ok

        2 ->
          :ok
      )
      """

      assert_same """
      (
        1 ->
          :ok

        2 ->
          :ok

        3 ->
          :ok
      )
      """
    end
  end

  describe "blocks" do
    test "empty" do
      assert_format "(;)", ""
      assert_format "quote do: (;)", "quote do: nil"
      assert_format "quote do end", "quote do\nend"
      assert_format "quote do ; end", "quote do\nend"
    end

    test "with multiple lines" do
      assert_same """
      foo = bar
      baz = bat
      """
    end

    test "with multiple lines with line limit" do
      code = """
      foo =
        bar(one)

      baz =
        bat(two)

      a(b)
      """

      assert_same code, @short_length

      code = """
      foo =
        bar(one)

      a(b)

      baz =
        bat(two)
      """

      assert_same code, @short_length

      code = """
      a(b)

      foo =
        bar(one)

      baz =
        bat(two)
      """

      assert_same code, @short_length

      code = """
      foo =
        bar(one)

      one =
        two(ghi)

      baz =
        bat(two)
      """

      assert_same code, @short_length
    end

    test "with multiple lines with line limit inside block" do
      code = """
      block do
        a =
          b(foo)

        c =
          d(bar)

        e =
          f(baz)
      end
      """

      assert_same code, @short_length
    end

    test "with multiple lines with cancel expressions" do
      code = """
      foo(%{
        key: 1
      })

      bar(%{
        key: 1
      })

      baz(%{
        key: 1
      })
      """

      assert_same code, @short_length
    end

    test "with heredoc" do
      assert_same ~S'''
      block do
        """
        a

        b

        c
        """
      end
      '''
    end

    test "keeps user newlines" do
      assert_same """
      defmodule Mod do
        field(:foo)
        field(:bar)
        field(:baz)
        belongs_to(:one)
        belongs_to(:two)
        timestamp()
        lock()
        has_many(:three)
        has_many(:four)
        :ok
        has_one(:five)
        has_one(:six)
        foo = 1
        bar = 2
        :before
        baz = 3
        :after
      end
      """

      bad = """
      defmodule Mod do
        field(:foo)

        field(:bar)

        field(:baz)


        belongs_to(:one)
        belongs_to(:two)


        timestamp()

        lock()


        has_many(:three)
        has_many(:four)


        :ok


        has_one(:five)
        has_one(:six)


        foo = 1
        bar = 2


        :before
        baz = 3
        :after
      end
      """

      good = """
      defmodule Mod do
        field(:foo)

        field(:bar)

        field(:baz)

        belongs_to(:one)
        belongs_to(:two)

        timestamp()

        lock()

        has_many(:three)
        has_many(:four)

        :ok

        has_one(:five)
        has_one(:six)

        foo = 1
        bar = 2

        :before
        baz = 3
        :after
      end
      """

      assert_format bad, good
    end

    test "with multiple defs" do
      assert_same """
      def foo(:one), do: 1
      def foo(:two), do: 2
      def foo(:three), do: 3
      """
    end

    test "with module attributes" do
      assert_same ~S'''
      defmodule Foo do
        @constant 1
        @constant 2

        @doc """
        foo
        """
        def foo do
          :ok
        end

        @spec bar :: 1
        @spec bar :: 2
        def bar do
          :ok
        end

        @other_constant 3

        @spec baz :: 4
        @doc """
        baz
        """
        def baz do
          :ok
        end

        @another_constant 5
        @another_constant 5

        @doc """
        baz
        """
        @spec baz :: 6
        def baz do
          :ok
        end
      end
      '''
    end

    test "as function arguments" do
      assert_same """
      fun(
        (
          foo
          bar
        )
      )
      """

      assert_same """
      assert true,
        do:
          (
            foo
            bar
          )
      """
    end
  end
end
