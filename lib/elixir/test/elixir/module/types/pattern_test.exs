# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team

Code.require_file("type_helper.exs", __DIR__)

defmodule Module.Types.PatternTest do
  use ExUnit.Case, async: true

  import TypeHelper
  import Module.Types.Descr

  describe "variables" do
    test "captures variables from simple assignment in head" do
      assert typecheck!([x = :foo], x) == dynamic(atom([:foo]))
      assert typecheck!([:foo = x], x) == dynamic(atom([:foo]))
    end

    test "captures variables from simple assignment in =" do
      assert typecheck!(
               (
                 x = :foo
                 x
               )
             ) == atom([:foo])
    end

    test "refines information across patterns" do
      assert typecheck!([%y{}, %x{}, x = y, x = Point], y) == dynamic(atom([Point]))
    end

    test "repeated refinements are ignored on reporting" do
      assert typeerror!([{name, arity}, arity = 123], hd(Atom.to_charlist(name))) |> strip_ansi() ==
               ~l"""
               incompatible types given to Kernel.hd/1:

                   hd(Atom.to_charlist(name))

               given types:

                   empty_list() or non_empty_list(integer())

               but expected one of:

                   non_empty_list(term(), term())

               where "name" was given the type:

                   # type: dynamic()
                   # from: types_test.ex
                   {name, arity}
               """
    end

    test "errors on conflicting refinements" do
      assert typeerror!([a = b, a = :foo, b = :bar], {a, b}) ==
               ~l"""
               the following pattern will never match:

                   a = b

               where "a" was given the type:

                   # type: dynamic(:foo)
                   # from: types_test.ex:LINE-1
                   a = :foo

               where "b" was given the type:

                   # type: dynamic(:bar)
                   # from: types_test.ex:LINE-1
                   b = :bar
               """
    end

    test "can be accessed even if they don't match" do
      assert typeerror!(
               (
                 # This will never match, info should not be "corrupted"
                 [info | _] = __ENV__.function
                 info
               )
             ) =~ "the following pattern will never match"
    end

    test "does not check underscore" do
      assert typecheck!(_ = raise("oops")) == none()
    end
  end

  describe "=" do
    test "precedence does not matter" do
      uri_type = typecheck!([x = %URI{}], x)

      assert typecheck!(
               (
                 x = %URI{} = URI.new!("/")
                 x
               )
             ) == uri_type

      assert typecheck!(
               (
                 %URI{} = x = URI.new!("/")
                 x
               )
             ) == uri_type
    end

    test "refines types" do
      assert typecheck!(
               [x, foo = :foo, bar = 123],
               (
                 {^foo, ^bar} = x
                 x
               )
             ) == dynamic(tuple([atom([:foo]), integer()]))
    end

    test "reports incompatible types" do
      assert typeerror!([x = {:ok, _}], [_ | _] = x) == ~l"""
             the following pattern will never match:

                 [_ | _] = x

             because the right-hand side has type:

                 dynamic({:ok, term()})

             where "x" was given the type:

                 # type: dynamic({:ok, term()})
                 # from: types_test.ex:LINE
                 x = {:ok, _}
             """
    end
  end

  describe "structs" do
    test "variable name" do
      assert typecheck!([%x{}], x) == dynamic(atom())
    end

    test "variable name fields" do
      assert typecheck!([x = %_{}], x.__struct__) == dynamic(atom())
      assert typecheck!([x = %_{}], x) == dynamic(open_map(__struct__: atom()))

      assert typecheck!([x = %m{}, m = Point], x) ==
               dynamic(open_map(__struct__: atom([Point])))

      assert typecheck!([m = Point, x = %m{}], x) ==
               dynamic(open_map(__struct__: atom([Point])))

      assert typeerror!([m = 123], %^m{} = %Point{}) ==
               ~l"""
               expected an atom as struct name:

                   %^m{}

               got type:

                   integer()

               where "m" was given the type:

                   # type: integer()
                   # from: types_test.ex:LINE-1
                   m = 123
               """
    end

    test "fields in guards" do
      assert typeerror!([x = %Point{}], x.foo_bar, :ok) ==
               ~l"""
               unknown key .foo_bar in expression:

                   x.foo_bar

               the given type does not have the given key:

                   dynamic(%Point{x: term(), y: term(), z: term()})

               where "x" was given the type:

                   # type: dynamic(%Point{})
                   # from: types_test.ex:LINE-1
                   x = %Point{}
               """
    end
  end

  describe "maps" do
    test "fields in patterns" do
      assert typecheck!([x = %{foo: :bar}], x) == dynamic(open_map(foo: atom([:bar])))
      assert typecheck!([x = %{123 => 456}], x) == dynamic(open_map())
      assert typecheck!([x = %{123 => 456, foo: :bar}], x) == dynamic(open_map(foo: atom([:bar])))
    end

    test "fields in guards" do
      assert typecheck!([x = %{foo: :bar}], x.bar, x) == dynamic(open_map(foo: atom([:bar])))
    end
  end

  describe "tuples" do
    test "in patterns" do
      assert typecheck!([x = {:ok, 123}], x) == dynamic(tuple([atom([:ok]), integer()]))
      assert typecheck!([{:x, y} = {x, :y}], {x, y}) == dynamic(tuple([atom([:x]), atom([:y])]))
    end
  end

  describe "lists" do
    test "in patterns" do
      assert typecheck!([x = [1, 2, 3]], x) ==
               dynamic(non_empty_list(integer()))

      assert typecheck!([x = [1, 2, 3 | y], y = :foo], x) ==
               dynamic(non_empty_list(integer(), atom([:foo])))

      assert typecheck!([x = [1, 2, 3 | y], y = [1.0, 2.0, 3.0]], x) ==
               dynamic(non_empty_list(union(integer(), float())))

      assert typecheck!([x = [:ok | z]], {x, z}) ==
               dynamic(tuple([non_empty_list(term(), term()), term()]))

      assert typecheck!([x = [y | z]], {x, y, z}) ==
               dynamic(tuple([non_empty_list(term(), term()), term(), term()]))
    end

    test "in patterns through ++" do
      assert typecheck!([x = [] ++ []], x) == dynamic(empty_list())

      assert typecheck!([x = [] ++ y, y = :foo], x) ==
               dynamic(atom([:foo]))

      assert typecheck!([x = [1, 2, 3] ++ y, y = :foo], x) ==
               dynamic(non_empty_list(integer(), atom([:foo])))

      assert typecheck!([x = [1, 2, 3] ++ y, y = [1.0, 2.0, 3.0]], x) ==
               dynamic(non_empty_list(union(integer(), float())))
    end

    test "with lists inside tuples inside lists" do
      assert typecheck!([[node_1 = {[arg]}, node_2 = {[arg]}]], {node_1, node_2, arg})
             |> equal?(
               dynamic(
                 tuple([
                   tuple([non_empty_list(term())]),
                   tuple([non_empty_list(term())]),
                   term()
                 ])
               )
             )
    end
  end

  describe "binaries" do
    test "ok" do
      assert typecheck!([<<x>>], x) == integer()
      assert typecheck!([<<x::float>>], x) == float()
      assert typecheck!([<<x::binary>>], x) == binary()
      assert typecheck!([<<x::utf8>>], x) == integer()
    end

    test "nested" do
      assert typecheck!([<<0, <<x::bitstring>>::binary>>], x) == binary()
    end

    test "error" do
      assert typeerror!([<<x::binary-size(2), x::float>>], x) == ~l"""
             incompatible types assigned to "x":

                 binary() !~ float()

             where "x" was given the types:

                 # type: binary()
                 # from: types_test.ex:LINE
                 <<x::binary-size(2), ...>>

                 # type: float()
                 # from: types_test.ex:LINE
                 <<..., x::float>>
             """

      assert typeerror!([<<x::float, x>>], x) == ~l"""
             incompatible types assigned to "x":

                 float() !~ integer()

             where "x" was given the types:

                 # type: float()
                 # from: types_test.ex:LINE
                 <<x::float, ...>>

                 # type: integer()
                 # from: types_test.ex:LINE
                 <<..., x>>

             #{hints(:inferred_bitstring_spec)}
             """
    end

    test "pin inference" do
      assert typecheck!(
               [x, y],
               (
                 <<^x>> = y
                 x
               )
             ) == dynamic(integer())
    end

    test "size ok" do
      assert typecheck!([<<x, y, _::size(x - y)>>], :ok) == atom([:ok])
    end

    test "size error" do
      assert typeerror!([<<x::float, _::size(x)>>], :ok) ==
               ~l"""
               expected an integer in binary size:

                   size(x)

               got type:

                   float()

               where "x" was given the type:

                   # type: float()
                   # from: types_test.ex:LINE-1
                   <<x::float, ...>>
               """
    end

    test "size pin inference" do
      assert typecheck!(
               [x, y],
               (
                 <<_::size(^x)>> = y
                 x
               )
             ) == dynamic(integer())
    end
  end
end
