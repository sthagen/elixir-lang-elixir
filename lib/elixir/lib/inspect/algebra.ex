# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule Inspect.Opts do
  @moduledoc """
  Defines the options used by the `Inspect` protocol.

  The following fields are available:

    * `:base` - prints integers and binaries as `:binary`, `:octal`, `:decimal`,
      or `:hex`. Defaults to `:decimal`.

    * `:binaries` - when `:as_binaries` all binaries will be printed in bit
      syntax.

      When `:as_strings` all binaries will be printed as strings, non-printable
      bytes will be escaped.

      When the default `:infer`, the binary will be printed as a string if `:base`
      is `:decimal` and if it is printable, otherwise in bit syntax. See
      `String.printable?/1` to learn when a string is printable.

    * `:charlists` - when `:as_charlists` all lists will be printed as charlists,
      non-printable elements will be escaped.

      When `:as_lists` all lists will be printed as lists.

      When the default `:infer`, the list will be printed as a charlist if it
      is printable, otherwise as list. See `List.ascii_printable?/1` to learn
      when a charlist is printable.

    * `:custom_options` (since v1.9.0) - a keyword list storing custom user-defined
      options. Useful when implementing the `Inspect` protocol for nested structs
      to pass the custom options through.

      It supports some pre-defined keys:

      - `:sort_maps` (since v1.14.4) - if set to `true`, sorts key-value pairs
        in maps. This can be helpful to make map inspection deterministic for
        testing, given maps key order is random.

    * `:inspect_fun` (since v1.9.0) - a function to build algebra documents.
      Defaults to `Inspect.Opts.default_inspect_fun/0`.

    * `:limit` - limits the number of items that are inspected for tuples,
      bitstrings, maps, lists and any other collection of items, with the exception of
      printable strings and printable charlists which use the `:printable_limit` option.
      It accepts a positive integer or `:infinity`. It defaults to `100` since
      `Elixir v1.19.0`, as it has better defaults to deal with nested collections.

    * `:pretty` - if set to `true` enables pretty printing. Defaults to `false`.

    * `:printable_limit` - limits the number of characters that are inspected
      on printable strings and printable charlists. You can use `String.printable?/1`
      and `List.ascii_printable?/1` to check if a given string or charlist is
      printable. If you don't want to limit the number of characters to a particular
      number, use `:infinity`. It accepts a positive integer or `:infinity`.
      Defaults to `4096`.

    * `:safe` - when `false`, failures while inspecting structs will be raised
      as errors instead of being wrapped in the `Inspect.Error` exception. This
      is useful when debugging failures and crashes for custom inspect
      implementations. Defaults to `true`.

    * `:structs` - when `false`, structs are not formatted by the inspect
      protocol, they are instead printed as maps. Defaults to `true`.

    * `:syntax_colors` - when set to a keyword list of colors the output is
      colorized. The keys are types and the values are the colors to use for
      each type (for example, `[number: :red, atom: :blue]`). Types can include
      `:atom`, `:binary`, `:boolean`, `:list`, `:map`, `:number`, `:regex`,
      `:string`, `:tuple`, or some types to represent AST like `:variable`,
      `:call`, and `:operator`.
      Custom data types may provide their own options.
      Colors can be any `t:IO.ANSI.ansidata/0` as accepted by `IO.ANSI.format/1`.
      A default list of colors can be retrieved from `IO.ANSI.syntax_colors/0`.

    * `:width` - number of characters per line used when pretty is `true` or when
      printing to IO devices. Set to `0` to force each item to be printed on its
      own line. If you don't want to limit the number of items to a particular
      number, use `:infinity`. Defaults to `80`.

  """

  # TODO: Remove :char_lists key on v2.0
  defstruct base: :decimal,
            binaries: :infer,
            char_lists: :infer,
            charlists: :infer,
            custom_options: [],
            inspect_fun: &Inspect.inspect/2,
            limit: 100,
            pretty: false,
            printable_limit: 4096,
            safe: true,
            structs: true,
            syntax_colors: [],
            width: 80

  @type color_key :: atom

  @type t :: %__MODULE__{
          base: :decimal | :binary | :hex | :octal,
          binaries: :infer | :as_binaries | :as_strings,
          charlists: :infer | :as_lists | :as_charlists,
          custom_options: keyword,
          inspect_fun: (any, t -> Inspect.Algebra.t()),
          limit: non_neg_integer | :infinity,
          pretty: boolean,
          printable_limit: non_neg_integer | :infinity,
          safe: boolean,
          structs: boolean,
          syntax_colors: [{color_key, IO.ANSI.ansidata()}],
          width: non_neg_integer | :infinity
        }

  @typedoc """
  Options for building an `Inspect.Opts` struct with `new/1`.
  """
  @type new_opt ::
          {:base, :decimal | :binary | :hex | :octal}
          | {:binaries, :infer | :as_binaries | :as_strings}
          | {:charlists, :infer | :as_lists | :as_charlists}
          | {:custom_options, keyword}
          | {:inspect_fun, (any, t -> Inspect.Algebra.t())}
          | {:limit, non_neg_integer | :infinity}
          | {:pretty, boolean}
          | {:printable_limit, non_neg_integer | :infinity}
          | {:safe, boolean}
          | {:structs, boolean}
          | {:syntax_colors, [{color_key, IO.ANSI.ansidata()}]}
          | {:width, non_neg_integer | :infinity}

  @doc """
  Builds an `Inspect.Opts` struct.
  """
  @doc since: "1.13.0"
  @spec new([new_opt()]) :: t
  def new(opts) do
    struct(%Inspect.Opts{inspect_fun: default_inspect_fun()}, opts)
  end

  @doc """
  Returns the default inspect function.
  """
  @doc since: "1.13.0"
  @spec default_inspect_fun() :: (term, t -> Inspect.Algebra.t())
  def default_inspect_fun do
    :persistent_term.get({__MODULE__, :inspect_fun}, &Inspect.inspect/2)
  end

  @doc """
  Sets the default inspect function.

  Set this option with care as it will change how all values
  in the system are inspected. The main use of this functionality
  is to provide an entry point to filter inspected values,
  in order for entities to comply with rules and legislations
  on data security and data privacy.

  It is **extremely discouraged** for libraries to set their own
  function as this must be controlled by applications. Libraries
  should instead define their own structs with custom inspect
  implementations. If a library must change the default inspect
  function, then it is best to ask users of your library to explicitly
  call `default_inspect_fun/1` with your function of choice.

  The default is `Inspect.inspect/2`.

  ## Examples

      previous_fun = Inspect.Opts.default_inspect_fun()

      Inspect.Opts.default_inspect_fun(fn
        %{address: _} = map, opts ->
          previous_fun.(%{map | address: "[REDACTED]"}, opts)

        value, opts ->
          previous_fun.(value, opts)
      end)

  """
  @doc since: "1.13.0"
  @spec default_inspect_fun((term, t -> Inspect.Algebra.t())) :: :ok
  def default_inspect_fun(fun) when is_function(fun, 2) do
    :persistent_term.put({__MODULE__, :inspect_fun}, fun)
  end
end

defmodule Inspect.Algebra do
  @moduledoc ~S"""
  A set of functions for creating and manipulating algebra
  documents.

  This module implements the functionality described in
  ["Strictly Pretty" (2000) by Christian Lindig][0] with small
  additions, like support for binary nodes and a break mode that
  maximises use of horizontal space.

      iex> Inspect.Algebra.line()
      :doc_line

      iex> "foo"
      "foo"

  With the functions in this module, we can concatenate different
  elements together and render them:

      iex> doc = Inspect.Algebra.concat(Inspect.Algebra.empty(), "foo")
      iex> Inspect.Algebra.format(doc, 80)
      "foo"

  The functions `nest/2`, `space/2` and `line/2` help you put the
  document together into a rigid structure. However, the document
  algebra gets interesting when using functions like `glue/3` and
  `group/1`. A glue inserts a break between two documents. A group
  indicates a document that must fit the current line, otherwise
  breaks are rendered as new lines. Let's glue two docs together
  with a break, group it and then render it:

      iex> doc = Inspect.Algebra.glue("a", " ", "b")
      iex> doc = Inspect.Algebra.group(doc)
      iex> Inspect.Algebra.format(doc, 80)
      "a b"

  Note that the break was represented as is, because we haven't reached
  a line limit. Once we do, it is replaced by a newline:

      iex> doc = Inspect.Algebra.glue(String.duplicate("a", 20), " ", "b")
      iex> doc = Inspect.Algebra.group(doc)
      iex> Inspect.Algebra.format(doc, 10)
      "aaaaaaaaaaaaaaaaaaaa\nb"

  This module uses the byte size to compute how much space there is
  left. If your document contains strings, then those need to be
  wrapped in `string/1`, which then relies on `String.length/1` to
  precompute the document size.

  Finally, this module also contains Elixir related functions, a bit
  tied to Elixir formatting, such as `to_doc/2`.

  ## Implementation details

  The implementation of `Inspect.Algebra` is based on the Strictly Pretty
  paper by [Lindig][0] which builds on top of previous pretty printing
  algorithms but is tailored to strict languages, such as Elixir.
  The core idea in the paper is the use of explicit document groups which
  are rendered as flat (breaks as spaces) or as break (breaks as newlines).

  This implementation provides two types of breaks: `:strict` and `:flex`.
  When a group does not fit, all strict breaks are treated as newlines.
  Flex breaks, however, are re-evaluated on every occurrence and may still
  be rendered flat. See `break/1` and `flex_break/1` for more information.

  This implementation also adds `force_unfit/1` and optimistic/pessimistic
  groups which give more control over the document fitting.

    [0]: https://lindig.github.io/papers/strictly-pretty-2000.pdf

  """

  @container_separator ","
  @tail_separator " |"
  @newline "\n"

  # Functional interface to "doc" records

  @type t ::
          binary
          | doc_nil
          | doc_cons
          | doc_line
          | doc_break
          | doc_collapse
          | doc_color
          | doc_fits
          | doc_force
          | doc_group
          | doc_nest
          | doc_string
          | doc_limit

  @typep doc_nil :: []
  defmacrop doc_nil do
    []
  end

  @typep doc_line :: :doc_line
  defmacrop doc_line do
    :doc_line
  end

  @typep doc_cons :: nonempty_improper_list(t, t)
  defmacrop doc_cons(left, right) do
    quote do: [unquote(left) | unquote(right)]
  end

  @typep doc_string :: {:doc_string, binary, non_neg_integer}
  defmacrop doc_string(string, length) do
    quote do: {:doc_string, unquote(string), unquote(length)}
  end

  @typep doc_limit :: {:doc_limit, t, pos_integer | :infinity}
  defmacrop doc_limit(doc, limit) do
    quote do: {:doc_limit, unquote(doc), unquote(limit)}
  end

  @typep doc_nest :: {:doc_nest, t, :cursor | :reset | non_neg_integer, :always | :break}
  defmacrop doc_nest(doc, indent, always_or_break) do
    quote do: {:doc_nest, unquote(doc), unquote(indent), unquote(always_or_break)}
  end

  @typep doc_break :: {:doc_break, binary, :flex | :strict}
  defmacrop doc_break(break, mode) do
    quote do: {:doc_break, unquote(break), unquote(mode)}
  end

  @typep doc_group :: {:doc_group, t, :normal | :optimistic | :pessimistic | :inherit}
  defmacrop doc_group(group, mode) do
    quote do: {:doc_group, unquote(group), unquote(mode)}
  end

  @typep doc_fits :: {:doc_fits, t, :enabled | :disabled}
  defmacrop doc_fits(group, mode) do
    quote do: {:doc_fits, unquote(group), unquote(mode)}
  end

  @typep doc_force :: {:doc_force, t}
  defmacrop doc_force(group) do
    quote do: {:doc_force, unquote(group)}
  end

  @typep doc_collapse :: {:doc_collapse, pos_integer()}
  defmacrop doc_collapse(count) do
    quote do: {:doc_collapse, unquote(count)}
  end

  @typep doc_color :: {:doc_color, t, IO.ANSI.ansidata()}
  defmacrop doc_color(doc, color) do
    quote do: {:doc_color, unquote(doc), unquote(color)}
  end

  @typedoc """
  Options for container documents.
  """
  @type container_opts :: [
          separator: String.t(),
          break: :strict | :flex | :maybe
        ]

  @docs [
    :doc_break,
    :doc_collapse,
    :doc_color,
    :doc_cons,
    :doc_fits,
    :doc_force,
    :doc_group,
    :doc_nest,
    :doc_string,
    :doc_limit
  ]

  defguard is_doc(doc)
           when is_list(doc) or is_binary(doc) or doc == doc_line() or
                  (is_tuple(doc) and elem(doc, 0) in @docs)

  defguardp is_width(width) when width == :infinity or (is_integer(width) and width >= 0)

  # Elixir + Inspect.Opts conveniences
  # These have the _doc suffix.

  @doc """
  Converts an Elixir term to an algebra document
  according to the `Inspect` protocol.

  In practice, one must prefer to use `to_doc_with_opts/2`
  over this function, as `to_doc_with_opts/2` returns the
  updated options from inspection.
  """
  @spec to_doc(any, Inspect.Opts.t()) :: t
  def to_doc(term, opts) do
    to_doc_with_opts(term, opts) |> elem(0)
  end

  @doc """
  Converts an Elixir term to an algebra document
  according to the `Inspect` protocol, alongside the updated options.

  This function is used when implementing the inspect protocol for
  a given type and you must convert nested terms to documents too.
  """
  @doc since: "1.19.0"
  @spec to_doc_with_opts(any, Inspect.Opts.t()) :: {t, Inspect.Opts.t()}
  def to_doc_with_opts(term, opts)

  def to_doc_with_opts(%_{} = struct, %Inspect.Opts{inspect_fun: fun} = opts) do
    if opts.structs do
      try do
        fun.(struct, opts)
      rescue
        caught_exception ->
          # Because we try to raise a nice error message in case
          # we can't inspect a struct, there is a chance the error
          # message itself relies on the struct being printed, so
          # we need to trap the inspected messages to guarantee
          # we won't try to render any failed instruct when building
          # the error message.
          if Process.get(:inspect_trap) do
            Inspect.Map.inspect_as_map(struct, opts)
          else
            try do
              Process.put(:inspect_trap, true)

              {doc_struct, _opts} =
                Inspect.Map.inspect_as_map(struct, %{
                  opts
                  | syntax_colors: [],
                    inspect_fun: Inspect.Opts.default_inspect_fun()
                })

              inspected_struct =
                doc_struct
                |> format(opts.width)
                |> IO.iodata_to_binary()

              inspect_error =
                Inspect.Error.exception(
                  exception: caught_exception,
                  stacktrace: __STACKTRACE__,
                  inspected_struct: inspected_struct
                )

              if opts.safe do
                opts = %{opts | inspect_fun: Inspect.Opts.default_inspect_fun()}
                Inspect.inspect(inspect_error, opts)
              else
                reraise(inspect_error, __STACKTRACE__)
              end
            after
              Process.delete(:inspect_trap)
            end
          end
      end
    else
      Inspect.Map.inspect_as_map(struct, opts)
    end
    |> pack_opts(opts)
  end

  def to_doc_with_opts(arg, %Inspect.Opts{inspect_fun: fun} = opts) do
    fun.(arg, opts) |> pack_opts(opts)
  end

  defp pack_opts({_doc, %Inspect.Opts{}} = doc_opts, _opts), do: doc_opts
  defp pack_opts(doc, opts), do: {doc, opts}

  @doc ~S"""
  Wraps `collection` in `left` and `right` according to limit and contents
  and returns only the container document.

  In practice, one must prefer to use `container_doc_with_opts/6`
  over this function, as `container_doc_with_opts/6` returns the
  updated options from inspection.
  """
  @doc since: "1.6.0"
  @spec container_doc(
          t,
          [term],
          t,
          Inspect.Opts.t(),
          (term, Inspect.Opts.t() -> t),
          container_opts()
        ) ::
          t
  def container_doc(left, collection, right, inspect_opts, fun, opts \\ []) do
    container_doc_with_opts(left, collection, right, inspect_opts, fun, opts) |> elem(0)
  end

  @doc ~S"""
  Wraps `collection` in `left` and `right` according to limit and contents.

  It uses the given `left` and `right` documents as surrounding and the
  separator document `separator` to separate items in `docs`. If all entries
  in the collection are simple documents (texts or strings), then this function
  attempts to put as much as possible on the same line. If they are not simple,
  only one entry is shown per line if they do not fit.

  The limit in the given `inspect_opts` is respected and when reached this
  function stops processing and outputs `"..."` instead.

  It returns a tuple with the algebra document and the updated options.

  ## Options

    * `:separator` - the separator used between each doc
    * `:break` - If `:strict`, always break between each element. If `:flex`,
      breaks only when necessary. If `:maybe`, chooses `:flex` only if all
      elements are text-based, otherwise is `:strict`

  ## Examples

      iex> inspect_opts = %Inspect.Opts{limit: :infinity}
      iex> fun = fn i, _opts -> to_string(i) end
      iex> {doc, _opts} = Inspect.Algebra.container_doc_with_opts("[", Enum.to_list(1..5), "]", inspect_opts, fun)
      iex> Inspect.Algebra.format(doc, 5) |> IO.iodata_to_binary()
      "[1,\n 2,\n 3,\n 4,\n 5]"

      iex> inspect_opts = %Inspect.Opts{limit: 3}
      iex> fun = fn i, _opts -> to_string(i) end
      iex> {doc, _opts} = Inspect.Algebra.container_doc_with_opts("[", Enum.to_list(1..5), "]", inspect_opts, fun)
      iex> Inspect.Algebra.format(doc, 20) |> IO.iodata_to_binary()
      "[1, 2, 3, ...]"

      iex> inspect_opts = %Inspect.Opts{limit: 3}
      iex> fun = fn i, _opts -> to_string(i) end
      iex> opts = [separator: "!"]
      iex> {doc, _opts} = Inspect.Algebra.container_doc_with_opts("[", Enum.to_list(1..5), "]", inspect_opts, fun, opts)
      iex> Inspect.Algebra.format(doc, 20) |> IO.iodata_to_binary()
      "[1! 2! 3! ...]"

  """
  @doc since: "1.19.0"
  @spec container_doc_with_opts(
          t,
          [term],
          t,
          Inspect.Opts.t(),
          (term, Inspect.Opts.t() -> t),
          container_opts()
        ) ::
          {t, Inspect.Opts.t()}
  def container_doc_with_opts(left, collection, right, inspect_opts, fun, opts \\ [])
      when is_doc(left) and is_list(collection) and is_doc(right) and is_function(fun, 2) and
             is_list(opts) do
    case collection do
      [] ->
        {concat(left, right), inspect_opts}

      _ ->
        break = Keyword.get(opts, :break, :maybe)
        separator = Keyword.get(opts, :separator, @container_separator)

        {docs, simple?, inspect_opts} =
          container_each(collection, inspect_opts, fun, [], break == :maybe)

        flex? = simple? or break == :flex
        docs = fold(docs, &join(&1, &2, flex?, separator))

        group =
          case flex? do
            true -> doc_group(concat(concat(left, nest(docs, 1)), right), :normal)
            false -> doc_group(glue(nest(glue(left, "", docs), 2), "", right), :normal)
          end

        {group, inspect_opts}
    end
  end

  defp container_each([], opts, _fun, acc, simple?) do
    {:lists.reverse(acc), simple?, opts}
  end

  defp container_each(_, opts, _fun, acc, simple?) when opts.limit <= 0 do
    {:lists.reverse(["..." | acc]), simple?, opts}
  end

  defp container_each([term | terms], opts, fun, acc, simple?) when is_list(terms) do
    {doc, opts} = call_container_fun(fun, term, opts)
    container_each(terms, opts, fun, [doc | acc], simple? and simple?(doc))
  end

  defp container_each([left | right], opts, fun, acc, simple?) do
    {left, opts} = call_container_fun(fun, left, opts)
    {right, _opts} = call_container_fun(fun, right, opts)
    simple? = simple? and simple?(left) and simple?(right)
    doc = join(left, right, simple?, @tail_separator)
    {:lists.reverse([doc | acc]), simple?, opts}
  end

  defp call_container_fun(fun, term, %{limit: bounded} = opts)
       when bounded <= 0 or bounded == :infinity do
    case fun.(term, opts) do
      {doc, %Inspect.Opts{} = opts} -> {doc, opts}
      doc -> {doc, opts}
    end
  end

  defp call_container_fun(fun, term, %{limit: limit} = opts) do
    changed_opts = %{opts | limit: limit - 1}

    case fun.(term, changed_opts) do
      {doc, %Inspect.Opts{} = opts} -> {doc, opts}
      doc_nil() -> {doc_nil(), opts}
      doc -> {doc, changed_opts}
    end
  end

  defp join(doc_nil(), doc_nil(), _, _), do: doc_nil()
  defp join(left, doc_nil(), _, _), do: left
  defp join(doc_nil(), right, _, _), do: right
  defp join(left, right, true, sep), do: flex_glue(concat(left, sep), right)
  defp join(left, right, false, sep), do: glue(concat(left, sep), right)

  defp simple?(doc_cons(left, right)), do: simple?(left) and simple?(right)
  defp simple?(doc_color(doc, _)), do: simple?(doc)
  defp simple?(doc_string(_, _)), do: true
  defp simple?(doc_nil()), do: true
  defp simple?(other), do: is_binary(other)

  @doc false
  @deprecated "Use a combination of concat/2 and nest/2 instead"
  def surround(left, doc, right) when is_doc(left) and is_doc(doc) and is_doc(right) do
    concat(concat(left, nest(doc, 1)), right)
  end

  @doc false
  @deprecated "Use Inspect.Algebra.container_doc/6 instead"
  def surround_many(
        left,
        docs,
        right,
        %Inspect.Opts{} = inspect,
        fun,
        separator \\ @container_separator
      )
      when is_doc(left) and is_list(docs) and is_doc(right) and is_function(fun, 2) do
    container_doc(left, docs, right, inspect, fun, separator: separator)
  end

  # TODO: Deprecate me on Elixir v1.23
  @doc deprecated: "Use color_doc/3 instead"
  def color(doc, key, opts) do
    color_doc(doc, key, opts)
  end

  @doc ~S"""
  Colors a document if the `color_key` has a color in the options.
  """
  @doc since: "1.18.0"
  @spec color_doc(t, Inspect.Opts.color_key(), Inspect.Opts.t()) :: t
  def color_doc(doc, color_key, %Inspect.Opts{syntax_colors: syntax_colors}) when is_doc(doc) do
    if precolor = Keyword.get(syntax_colors, color_key) do
      postcolor = Keyword.get(syntax_colors, :reset, :reset)
      concat(doc_color(doc, ansi(precolor)), doc_color(empty(), ansi(postcolor)))
    else
      doc
    end
  end

  defp ansi(color) do
    color
    |> IO.ANSI.format_fragment(true)
    |> IO.iodata_to_binary()
  end

  # Algebra API

  @compile {:inline,
            empty: 0,
            concat: 2,
            break: 0,
            break: 1,
            glue: 2,
            glue: 3,
            flex_break: 0,
            flex_break: 1,
            flex_glue: 2,
            flex_glue: 3}

  @doc """
  Returns a document entity used to represent nothingness.

  ## Examples

      iex> Inspect.Algebra.empty()
      []

  """
  @spec empty() :: doc_nil()
  def empty, do: doc_nil()

  @doc ~S"""
  Creates a document represented by string.

  While `Inspect.Algebra` accepts binaries as documents,
  those are counted by binary size. On the other hand,
  `string` documents are measured in terms of graphemes
  towards the document size.

  ## Examples

  The following document has 10 bytes and therefore it
  does not format to width 9 without breaks:

      iex> doc = Inspect.Algebra.glue("olá", " ", "mundo")
      iex> doc = Inspect.Algebra.group(doc)
      iex> Inspect.Algebra.format(doc, 9)
      "olá\nmundo"

  However, if we use `string`, then the string length is
  used, instead of byte size, correctly fitting:

      iex> string = Inspect.Algebra.string("olá")
      iex> doc = Inspect.Algebra.glue(string, " ", "mundo")
      iex> doc = Inspect.Algebra.group(doc)
      iex> Inspect.Algebra.format(doc, 9)
      "olá mundo"

  """
  @doc since: "1.6.0"
  @spec string(String.t()) :: doc_string
  def string(string) when is_binary(string) do
    doc_string(string, String.length(string))
  end

  @doc ~S"""
  Concatenates two document entities returning a new document.

  ## Examples

      iex> doc = Inspect.Algebra.concat("hello", "world")
      iex> Inspect.Algebra.format(doc, 80)
      "helloworld"

  """
  @spec concat(t, t) :: t
  def concat(doc1, doc2) when is_doc(doc1) and is_doc(doc2) do
    doc_cons(doc1, doc2)
  end

  @doc ~S"""
  Disable any rendering limit while rendering the given document.

  ## Examples

      iex> doc = Inspect.Algebra.glue("hello", "world") |> Inspect.Algebra.group()
      iex> Inspect.Algebra.format(doc, 10)
      "hello\nworld"
      iex> doc = Inspect.Algebra.no_limit(doc)
      iex> Inspect.Algebra.format(doc, 10)
      "hello world"

  """
  @doc since: "1.14.0"
  @spec no_limit(t) :: t
  def no_limit(doc) do
    doc_limit(doc, :infinity)
  end

  @doc ~S"""
  Concatenates a list of documents returning a new document.

  ## Examples

      iex> doc = Inspect.Algebra.concat(["a", "b", "c"])
      iex> Inspect.Algebra.format(doc, 80)
      "abc"

  """
  @spec concat([t]) :: t
  def concat(docs) when is_list(docs) do
    fold(docs, &concat(&1, &2))
  end

  @doc ~S"""
  Colors a document with the given color (preceding the document itself).
  """
  @doc since: "1.18.0"
  @spec color(t, binary) :: t
  def color(doc, color) when is_doc(doc) and is_binary(color) do
    doc_color(doc, color)
  end

  @doc ~S"""
  Nests the given document at the given `level`.

  If `level` is an integer, that's the indentation appended
  to line breaks whenever they occur. If the level is `:cursor`,
  the current position of the "cursor" in the document becomes
  the nesting. If the level is `:reset`, it is set back to 0.

  `mode` can be `:always`, which means nesting always happen,
  or `:break`, which means nesting only happens inside a group
  that has been broken.

  ## Examples

      iex> doc = Inspect.Algebra.nest(Inspect.Algebra.glue("hello", "world"), 5)
      iex> doc = Inspect.Algebra.group(doc)
      iex> Inspect.Algebra.format(doc, 5)
      "hello\n     world"

  """
  @spec nest(t, non_neg_integer | :cursor | :reset, :always | :break) :: doc_nest | t
  def nest(doc, level, mode \\ :always)

  def nest(doc, :cursor, mode) when is_doc(doc) and mode in [:always, :break] do
    doc_nest(doc, :cursor, mode)
  end

  def nest(doc, :reset, mode) when is_doc(doc) and mode in [:always, :break] do
    doc_nest(doc, :reset, mode)
  end

  def nest(doc, 0, _mode) when is_doc(doc) do
    doc
  end

  def nest(doc, level, mode)
      when is_doc(doc) and is_integer(level) and level > 0 and mode in [:always, :break] do
    doc_nest(doc, level, mode)
  end

  @doc ~S"""
  Returns a break document based on the given `string`.

  This break can be rendered as a linebreak or as the given `string`,
  depending on the `mode` of the chosen layout.

  ## Examples

  Let's create a document by concatenating two strings with a break between
  them:

      iex> doc = Inspect.Algebra.concat(["a", Inspect.Algebra.break("\t"), "b"])
      iex> Inspect.Algebra.format(doc, 80)
      "a\tb"

  Note that the break was represented with the given string, because we didn't
  reach a line limit. Once we do, it is replaced by a newline:

      iex> break = Inspect.Algebra.break("\t")
      iex> doc = Inspect.Algebra.concat([String.duplicate("a", 20), break, "b"])
      iex> doc = Inspect.Algebra.group(doc)
      iex> Inspect.Algebra.format(doc, 10)
      "aaaaaaaaaaaaaaaaaaaa\nb"

  """
  @spec break(binary) :: doc_break
  def break(string \\ " ") when is_binary(string) do
    doc_break(string, :strict)
  end

  @doc """
  Collapse any new lines and whitespace following this
  node, emitting up to `max` new lines.
  """
  @doc since: "1.6.0"
  @spec collapse_lines(pos_integer) :: doc_collapse
  def collapse_lines(max) when is_integer(max) and max > 0 do
    doc_collapse(max)
  end

  @doc """
  Considers the next break as fit.
  """
  # TODO: Deprecate me on Elixir v1.23
  @doc deprecated: "Pass the optimistic/pessimistic type to group/2 instead"
  @spec next_break_fits(t, :enabled | :disabled) :: doc_fits
  def next_break_fits(doc, mode \\ :enabled)
      when is_doc(doc) and mode in [:enabled, :disabled] do
    doc_fits(doc, mode)
  end

  @doc """
  Forces the current group to be unfit.
  """
  @doc since: "1.6.0"
  @spec force_unfit(t) :: doc_force
  def force_unfit(doc) when is_doc(doc) do
    doc_force(doc)
  end

  @doc """
  Returns a flex break document based on the given `string`.

  A flex break still causes a group to break, like `break/1`,
  but it is re-evaluated when the documented is rendered.

  For example, take a group document represented as `[1, 2, 3]`
  where the space after every comma is a break. When the document
  above does not fit a single line, all breaks are enabled,
  causing the document to be rendered as:

      [1,
       2,
       3]

  However, if flex breaks are used, then each break is re-evaluated
  when rendered, so the document could be possible rendered as:

      [1, 2,
       3]

  Hence the name "flex". they are more flexible when it comes
  to the document fitting. On the other hand, they are more expensive
  since each break needs to be re-evaluated.

  This function is used by `container_doc/6` and friends to the
  maximum number of entries on the same line.
  """
  @doc since: "1.6.0"
  @spec flex_break(binary) :: doc_break
  def flex_break(string \\ " ") when is_binary(string) do
    doc_break(string, :flex)
  end

  @doc """
  Glues two documents (`doc1` and `doc2`) inserting a
  `flex_break/1` given by `break_string` between them.

  This function is used by `container_doc/6` and friends
  to the maximum number of entries on the same line.
  """
  @doc since: "1.6.0"
  @spec flex_glue(t, binary, t) :: t
  def flex_glue(doc1, break_string \\ " ", doc2) when is_binary(break_string) do
    concat(doc1, concat(flex_break(break_string), doc2))
  end

  @doc ~S"""
  Glues two documents (`doc1` and `doc2`) inserting the given
  break `break_string` between them.

  For more information on how the break is inserted, see `break/1`.

  ## Examples

      iex> doc = Inspect.Algebra.glue("hello", "world")
      iex> Inspect.Algebra.format(doc, 80)
      "hello world"

      iex> doc = Inspect.Algebra.glue("hello", "\t", "world")
      iex> Inspect.Algebra.format(doc, 80)
      "hello\tworld"

  """
  @spec glue(t, binary, t) :: t
  def glue(doc1, break_string \\ " ", doc2) when is_binary(break_string) do
    concat(doc1, concat(break(break_string), doc2))
  end

  @doc ~S"""
  Returns a group containing the specified document `doc`.

  Documents in a group are attempted to be rendered together
  to the best of the renderer ability. If there are `break/1`s
  in the group and the group does not fit the given width,
  the breaks are converted into lines. Otherwise the breaks
  are rendered as text based on their string contents.

  There are three types of groups, described next.

  ## Group modes

    * `:normal` - the group fits if it fits within the given width

    * `:optimistic` - the group fits if it fits within the given
      width. However, when nested within another group, the parent
      group will assume this group fits as long as it has a single
      break, even if the optimistic group has a `force_unfit/1`
      document within it. Overall, this has an effect similar
      to swapping the order groups break. For example, if you have
      a `parent_group(child_group)` and they do not fit, the parent
      converts breaks into newlines first, allowing the child to compute
      if it fits. However, if the child group is optimistic and it
      has breaks, then the parent assumes it fits, leaving the overall
      fitting decision to the child

    * `:pessimistic` - the group fits if it fits within the given
      width. However it disables any optimistic group within it

  ## Examples

      iex> doc =
      ...>   Inspect.Algebra.group(
      ...>     Inspect.Algebra.concat(
      ...>       Inspect.Algebra.group(
      ...>         Inspect.Algebra.concat(
      ...>           "Hello,",
      ...>           Inspect.Algebra.concat(
      ...>             Inspect.Algebra.break(),
      ...>             "A"
      ...>           )
      ...>         )
      ...>       ),
      ...>       Inspect.Algebra.concat(
      ...>         Inspect.Algebra.break(),
      ...>         "B"
      ...>       )
      ...>     )
      ...>   )
      iex> Inspect.Algebra.format(doc, 80)
      "Hello, A B"
      iex> Inspect.Algebra.format(doc, 6)
      "Hello,\nA\nB"

  ## Mode examples

  The different groups modes are used by Elixir's code formatter
  to avoid breaking code at some specific locations. For example,
  consider this code:

      some_function_call(%{..., key: value, ...})

  Now imagine that this code does not fit its line. The code
  formatter introduces breaks inside `(` and `)` and inside
  `%{` and `}`, each within their own group. Therefore the
  document would break as:

      some_function_call(
        %{
          ...,
          key: value,
          ...
        }
      )

  To address this, the formatter marks the inner group as optimistic.
  This means the first group, which is `(...)` will consider the document
  fits and avoids adding breaks around the parens. So overall the code
  is formatted as:

      some_function_call(%{
        ...,
        key: value,
        ...
      })

  """
  @spec group(t, :normal | :optimistic | :pessimistic) :: doc_group
  def group(doc, mode \\ :normal) when is_doc(doc) do
    doc_group(
      doc,
      case mode do
        # TODO: Deprecate :self and :inherit on Elixir v1.23
        :self -> :normal
        :inherit -> :inherit
        mode when mode in [:normal, :optimistic, :pessimistic] -> mode
      end
    )
  end

  @doc ~S"""
  Inserts a mandatory single space between two documents.

  ## Examples

      iex> doc = Inspect.Algebra.space("Hughes", "Wadler")
      iex> Inspect.Algebra.format(doc, 5)
      "Hughes Wadler"

  """
  @spec space(t, t) :: t
  def space(doc1, doc2), do: concat(doc1, concat(" ", doc2))

  @doc ~S"""
  A mandatory linebreak.

  A group with linebreaks will fit if all lines in the group fit.

  ## Examples

      iex> doc =
      ...>   Inspect.Algebra.concat(
      ...>     Inspect.Algebra.concat(
      ...>       "Hughes",
      ...>       Inspect.Algebra.line()
      ...>     ),
      ...>     "Wadler"
      ...>   )
      iex> Inspect.Algebra.format(doc, 80)
      "Hughes\nWadler"

  """
  @doc since: "1.6.0"
  @spec line() :: t
  def line(), do: doc_line()

  @doc ~S"""
  Inserts a mandatory linebreak between two documents.

  See `line/0`.

  ## Examples

      iex> doc = Inspect.Algebra.line("Hughes", "Wadler")
      iex> Inspect.Algebra.format(doc, 80)
      "Hughes\nWadler"

  """
  @spec line(t, t) :: t
  def line(doc1, doc2), do: concat(doc1, concat(line(), doc2))

  # TODO: Deprecate me on Elixir v1.23
  @doc deprecated: "Use fold/2 instead"
  def fold_doc(docs, folder_fun), do: fold(docs, folder_fun)

  @doc ~S"""
  Folds a list of documents into a document using the given folder function.

  The list of documents is folded "from the right"; in that, this function is
  similar to `List.foldr/3`, except that it doesn't expect an initial
  accumulator and uses the last element of `docs` as the initial accumulator.

  ## Examples

      iex> docs = ["A", "B", "C"]
      iex> docs =
      ...>   Inspect.Algebra.fold(docs, fn doc, acc ->
      ...>     Inspect.Algebra.concat([doc, "!", acc])
      ...>   end)
      iex> Inspect.Algebra.format(docs, 80)
      "A!B!C"

  """
  @doc since: "1.18.0"
  @spec fold([t], (t, t -> t)) :: t
  def fold(docs, folder_fun)

  def fold([], _folder_fun), do: empty()
  def fold([doc], _folder_fun), do: doc

  def fold([doc | docs], folder_fun) when is_function(folder_fun, 2),
    do: folder_fun.(doc, fold(docs, folder_fun))

  @doc ~S"""
  Formats a given document for a given width.

  Takes the maximum width and a document to print as its arguments
  and returns an IO data representation of the best layout for the
  document to fit in the given width.

  The document starts flat (without breaks) until a group is found.

  ## Examples

      iex> doc = Inspect.Algebra.glue("hello", " ", "world")
      iex> doc = Inspect.Algebra.group(doc)
      iex> doc |> Inspect.Algebra.format(30) |> IO.iodata_to_binary()
      "hello world"
      iex> doc |> Inspect.Algebra.format(10) |> IO.iodata_to_binary()
      "hello\nworld"

  """
  @spec format(t, non_neg_integer | :infinity) :: iodata
  def format(doc, width) when is_doc(doc) and is_width(width) do
    format(width, 0, [{0, :flat, doc}], <<>>)
  end

  # Type representing the document mode to be rendered:
  #
  #   * flat - represents a document with breaks as flats (a break may fit, as it may break)
  #   * break - represents a document with breaks as breaks (a break always fits, since it breaks)
  #
  # These other two modes only affect fitting:
  #
  #   * flat_no_break - represents a document with breaks as flat not allowed to enter in break mode
  #   * break_no_flat - represents a document with breaks as breaks not allowed to enter in flat mode
  #
  @typep mode :: :flat | :flat_no_break | :break | :break_no_flat

  @spec fits?(
          width :: non_neg_integer() | :infinity,
          column :: non_neg_integer(),
          break? :: boolean(),
          entries
        ) :: boolean()
        when entries:
               maybe_improper_list(
                 {integer(), mode(), t()} | :group_over,
                 {:tail, boolean(), entries} | []
               )

  # We need at least a break to consider the document does not fit since a
  # large document without breaks has no option but fitting its current line.
  #
  # In case we have groups and the group fits, we need to consider the group
  # parent without the child breaks, hence {:tail, b?, t} below.
  defp fits?(w, k, b?, _) when k > w and b?, do: false
  defp fits?(_, _, _, []), do: true
  defp fits?(w, k, _, {:tail, b?, t}), do: fits?(w, k, b?, t)

  ## Group over
  # If we get to the end of the group and if fits, it is because
  # something already broke elsewhere, so we can consider the group
  # fits. This only appears when checking if a flex break and fitting.

  defp fits?(_w, _k, b?, [:group_over | _]),
    do: b?

  ## Flat no break

  defp fits?(w, k, b?, [{i, _, doc_fits(x, :disabled)} | t]),
    do: fits?(w, k, b?, [{i, :flat_no_break, x} | t])

  defp fits?(w, k, b?, [{i, :flat_no_break, doc_fits(x, _)} | t]),
    do: fits?(w, k, b?, [{i, :flat_no_break, x} | t])

  defp fits?(w, k, b?, [{i, _, doc_group(x, :pessimistic)} | t]),
    do: fits?(w, k, b?, [{i, :flat_no_break, x} | t])

  defp fits?(w, k, b?, [{i, :flat_no_break, doc_group(x, _)} | t]),
    do: fits?(w, k, b?, [{i, :flat_no_break, x} | t])

  ## Breaks no flat

  defp fits?(w, k, b?, [{i, _, doc_fits(x, :enabled)} | t]),
    do: fits?(w, k, b?, [{i, :break_no_flat, x} | t])

  defp fits?(w, k, b?, [{i, _, doc_group(x, :optimistic)} | t]),
    do: fits?(w, k, b?, [{i, :break_no_flat, x} | t])

  defp fits?(w, k, b?, [{i, :break_no_flat, doc_force(x)} | t]),
    do: fits?(w, k, b?, [{i, :break_no_flat, x} | t])

  defp fits?(_, _, _, [{_, :break_no_flat, doc_break(_, _)} | _]), do: true
  defp fits?(_, _, _, [{_, :break_no_flat, doc_line()} | _]), do: true

  ## Breaks

  defp fits?(_, _, _, [{_, :break, doc_break(_, _)} | _]), do: true
  defp fits?(_, _, _, [{_, :break, doc_line()} | _]), do: true

  defp fits?(w, k, b?, [{i, :break, doc_group(x, _)} | t]),
    do: fits?(w, k, b?, [{i, :flat, x} | {:tail, b?, t}])

  ## Catch all

  defp fits?(w, _, _, [{i, _, doc_line()} | t]), do: fits?(w, i, false, t)
  defp fits?(w, k, b?, [{_, _, doc_nil()} | t]), do: fits?(w, k, b?, t)
  defp fits?(w, _, b?, [{i, _, doc_collapse(_)} | t]), do: fits?(w, i, b?, t)
  defp fits?(w, k, b?, [{i, m, doc_color(x, _)} | t]), do: fits?(w, k, b?, [{i, m, x} | t])
  defp fits?(w, k, b?, [{_, _, doc_string(_, l)} | t]), do: fits?(w, k + l, b?, t)
  defp fits?(w, k, b?, [{_, _, s} | t]) when is_binary(s), do: fits?(w, k + byte_size(s), b?, t)
  defp fits?(_, _, _, [{_, _, doc_force(_)} | _]), do: false
  defp fits?(w, k, _, [{_, _, doc_break(s, _)} | t]), do: fits?(w, k + byte_size(s), true, t)
  defp fits?(w, k, b?, [{i, m, doc_nest(x, _, :break)} | t]), do: fits?(w, k, b?, [{i, m, x} | t])

  defp fits?(w, k, b?, [{i, m, doc_nest(x, j, _)} | t]),
    do: fits?(w, k, b?, [{apply_nesting(i, k, j), m, x} | t])

  defp fits?(w, k, b?, [{i, m, doc_cons(x, y)} | t]),
    do: fits?(w, k, b?, [{i, m, x}, {i, m, y} | t])

  defp fits?(w, k, b?, [{i, m, doc_group(x, _)} | t]),
    do: fits?(w, k, b?, [{i, m, x} | {:tail, b?, t}])

  defp fits?(w, k, b?, [{i, m, doc_limit(x, :infinity)} | t]) when w != :infinity,
    do: fits?(:infinity, k, b?, [{i, :flat, x}, {i, m, doc_limit(empty(), w)} | t])

  defp fits?(_w, k, b?, [{i, m, doc_limit(x, w)} | t]),
    do: fits?(w, k, b?, [{i, m, x} | t])

  @spec format(
          width :: non_neg_integer() | :infinity,
          column :: non_neg_integer(),
          [{integer, mode, t} | :group_over],
          binary
        ) :: iodata
  defp format(_, _, [], acc), do: acc

  defp format(w, k, [{_, _, doc_nil()} | t], acc),
    do: format(w, k, t, acc)

  defp format(w, _, [{i, _, doc_line()} | t], acc),
    do: format(w, i, t, <<acc::binary, indent(i)::binary>>)

  defp format(w, k, [{i, m, doc_cons(x, y)} | t], acc),
    do: format(w, k, [{i, m, x}, {i, m, y} | t], acc)

  defp format(w, k, [{i, m, doc_color(x, c)} | t], acc),
    do: format(w, k, [{i, m, x} | t], <<acc::binary, c::binary>>)

  defp format(w, k, [{_, _, doc_string(s, l)} | t], acc),
    do: format(w, k + l, t, <<acc::binary, s::binary>>)

  defp format(w, k, [{_, _, s} | t], acc) when is_binary(s),
    do: format(w, k + byte_size(s), t, <<acc::binary, s::binary>>)

  defp format(w, k, [{i, m, doc_force(x)} | t], acc),
    do: format(w, k, [{i, m, x} | t], acc)

  defp format(w, k, [{i, m, doc_fits(x, _)} | t], acc),
    do: format(w, k, [{i, m, x} | t], acc)

  defp format(w, _, [{i, _, doc_collapse(max)} | t], acc),
    do: [acc | collapse(List.wrap(format(w, i, t, <<>>)), max, 0, i)]

  # Flex breaks are conditional to the document and the mode
  defp format(w, k, [{i, m, doc_break(s, :flex)} | t], acc) do
    k = k + byte_size(s)

    if w == :infinity or m == :flat or fits?(w, k, true, t) do
      format(w, k, t, <<acc::binary, s::binary>>)
    else
      format(w, i, t, <<acc::binary, indent(i)::binary>>)
    end
  end

  # Strict breaks are conditional to the mode
  defp format(w, k, [{i, mode, doc_break(s, :strict)} | t], acc) do
    if mode == :break do
      format(w, i, t, <<acc::binary, indent(i)::binary>>)
    else
      format(w, k + byte_size(s), t, <<acc::binary, s::binary>>)
    end
  end

  # Nesting is conditional to the mode.
  defp format(w, k, [{i, mode, doc_nest(x, j, nest)} | t], acc) do
    if nest == :always or (nest == :break and mode == :break) do
      format(w, k, [{apply_nesting(i, k, j), mode, x} | t], acc)
    else
      format(w, k, [{i, mode, x} | t], acc)
    end
  end

  # Groups must do the fitting decision.
  defp format(w, k, [:group_over | t], acc) do
    format(w, k, t, acc)
  end

  # TODO: Deprecate me in Elixir v1.23
  defp format(w, k, [{i, :break, doc_group(x, :inherit)} | t], acc) do
    format(w, k, [{i, :break, x} | t], acc)
  end

  defp format(w, k, [{i, :flat, doc_group(x, :optimistic)} | t], acc) do
    if w == :infinity or fits?(w, k, false, [{i, :flat, x} | t]) do
      format(w, k, [{i, :flat, x}, :group_over | t], acc)
    else
      format(w, k, [{i, :break, x}, :group_over | t], acc)
    end
  end

  defp format(w, k, [{i, _, doc_group(x, _)} | t], acc) do
    if w == :infinity or fits?(w, k, false, [{i, :flat, x}]) do
      format(w, k, [{i, :flat, x}, :group_over | t], acc)
    else
      format(w, k, [{i, :break, x}, :group_over | t], acc)
    end
  end

  # Limit is set to infinity and then reverts
  defp format(w, k, [{i, m, doc_limit(x, :infinity)} | t], acc) when w != :infinity do
    format(:infinity, k, [{i, :flat, x}, {i, m, doc_limit(empty(), w)} | t], acc)
  end

  defp format(_w, k, [{i, m, doc_limit(x, w)} | t], acc) do
    format(w, k, [{i, m, x} | t], acc)
  end

  defp collapse(["\n" <> rest | t], max, count, i) do
    collapse([strip_whitespace(rest) | t], max, count + 1, i)
  end

  defp collapse(["" | t], max, count, i) do
    collapse(t, max, count, i)
  end

  defp collapse(t, max, count, i) do
    [:binary.copy("\n", min(max, count)), :binary.copy(" ", i) | t]
  end

  defp strip_whitespace(" " <> rest), do: strip_whitespace(rest)
  defp strip_whitespace(rest), do: rest

  defp apply_nesting(_, k, :cursor), do: k
  defp apply_nesting(_, _, :reset), do: 0
  defp apply_nesting(i, _, j), do: i + j

  defp indent(0), do: @newline
  defp indent(i), do: @newline <> :binary.copy(" ", i)
end
