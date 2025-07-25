<!--
  SPDX-License-Identifier: Apache-2.0
  SPDX-FileCopyrightText: 2021 The Elixir Team
  SPDX-FileCopyrightText: 2012 Plataformatec
-->

# Compatibility and deprecations

Elixir is versioned according to a vMAJOR.MINOR.PATCH schema.

Elixir is currently at major version v1. A new backwards compatible minor release happens every 6 months. Patch releases are not scheduled and are made whenever there are bug fixes or security patches.

Elixir applies bug fixes only to the latest minor branch. Security patches are available for the last 5 minor branches:

Elixir version | Support
:------------- | :-----------------------------
1.20           | Development
1.19           | Bug fixes and security patches
1.18           | Security patches only
1.17           | Security patches only
1.16           | Security patches only
1.15           | Security patches only

New releases are announced in the read-only [announcements mailing list](https://groups.google.com/group/elixir-lang-ann). All security releases [will be tagged with `[security]`](https://groups.google.com/forum/#!searchin/elixir-lang-ann/%5Bsecurity%5D%7Csort:date).

There are currently no plans for a major v2 release.

## Between non-major Elixir versions

Elixir minor and patch releases are backwards compatible: well-defined behaviors and documented APIs in a given version will continue working on future versions.

Although we expect the vast majority of programs to remain compatible over time, it is impossible to guarantee that no future change will break any program. Under some unlikely circumstances, we may introduce changes that break existing code:

  * Security: a security issue in the implementation may arise whose resolution requires backwards incompatible changes. We reserve the right to address such security issues.

  * Bugs: if an API has undesired behavior, a program that depends on the buggy behavior may break if the bug is fixed. We reserve the right to fix such bugs.

  * Compiler front-end: improvements may be done to the compiler, introducing new warnings for ambiguous modes and providing more detailed error messages. Those can lead to compilation errors (when running with `--warning-as-errors`) or tooling failures when asserting on specific error messages (although one should avoid such). We reserve the right to do such improvements.

  * Imports: new functions may be added to the `Kernel` module, which is auto-imported. They may collide with local functions defined in your modules. Collisions can be resolved in a backwards compatible fashion using `import Kernel, except: [...]` with a list of all functions you don't want to be imported from `Kernel`. We reserve the right to do such additions.

In order to continue evolving the language without introducing breaking changes, Elixir will rely on deprecations to demote certain practices and promote new ones. Our deprecation policy is outlined in the ["Deprecations" section](#deprecations).

The only exception to the compatibility guarantees above are experimental features, which will be explicitly marked as such, and do not provide any compatibility guarantee until they are stabilized.

## Between Elixir and Erlang/OTP

Erlang/OTP versioning is independent from the versioning of Elixir. Erlang releases a new major version yearly. Our goal is to support the last three Erlang major versions by the time Elixir is released. The compatibility table is shown below.

Elixir version | Supported Erlang/OTP versions
:------------- | :-------------------------------
1.20           | 26 - 28
1.19           | 26 - 28
1.18           | 25 - 27
1.17           | 25 - 27
1.16           | 24 - 26
1.15           | 24 - 26
1.14           | 23 - 25 (and Erlang/OTP 26 from v1.14.5)
1.13           | 22 - 24 (and Erlang/OTP 25 from v1.13.4)
1.12           | 22 - 24
1.11           | 21 - 23 (and Erlang/OTP 24 from v1.11.4)
1.10           | 21 - 22 (and Erlang/OTP 23 from v1.10.3)
1.9            | 20 - 22
1.8            | 20 - 22
1.7            | 19 - 22
1.6            | 19 - 20 (and Erlang/OTP 21 from v1.6.6)
1.5            | 18 - 20
1.4            | 18 - 19 (and Erlang/OTP 20 from v1.4.5)
1.3            | 18 - 19
1.2            | 18 - 18 (and Erlang/OTP 19 from v1.2.6)
1.1            | 17 - 18
1.0            | 17 - 17 (and Erlang/OTP 18 from v1.0.5)

Elixir may add compatibility to new Erlang/OTP versions on patch releases, such as support for Erlang/OTP 20 in v1.4.5. Those releases are made for convenience and typically contain the minimum changes for Elixir to run without errors, if any changes are necessary. Only the next minor release, in this case v1.5.0, effectively leverages the new features provided by the latest Erlang/OTP release.

## Deprecations

### Policy

Elixir deprecations happen in 3 steps:

  1. The feature is soft-deprecated. It means both CHANGELOG and documentation must list the feature as deprecated but no warning is effectively emitted by running the code. There is no requirement to soft-deprecate a feature.

  2. The feature is effectively deprecated by emitting warnings on usage. This is also known as hard-deprecation. In order to deprecate a feature, the proposed alternative MUST exist for AT LEAST THREE minor versions. For example, `Enum.uniq/2` was soft-deprecated in favor of `Enum.uniq_by/2` in Elixir v1.1. This means a deprecation warning may only be emitted by Elixir v1.4 or later.

  3. The feature is removed. This can only happen on major releases. This means deprecated features in Elixir v1.x shall only be removed by Elixir v2.x.

### Table of deprecations

The first column is the version the feature was hard deprecated. The second column shortly describes the deprecated feature and the third column explains the replacement and from which the version the replacement is available from.

Version | Deprecated feature                                  | Replaced by (available since)
:-------| :-------------------------------------------------- | :---------------------------------------------------------------
[v1.20] | `<<x::size(y)>>` in patterns without `^`            | `<<x::size(^y)>>`
[v1.20] | `File.stream!(path, modes, lines_or_bytes)`         | `File.stream!(path, lines_or_bytes, modes)`
[v1.20] | `Kernel.ParallelCompiler.async/1`                   | `Kernel.ParallelCompiler.pmap/2`
[v1.20] | `Logger.*_backend` functions                        | The `LoggerBackends` module from `:logger_backends` package
[v1.20] | `Logger.enable/1` / `Logger.disable/1`              | `Logger.put_process_level/2` and `Logger.delete_process_level/1`
[v1.19] | CLI configuration in `def project` inside `mix.exs` | Moving it to `def cli` (v1.14)
[v1.19] | Using `,` to separate tasks in `mix do`             | Using `+` (v1.14)
[v1.19] | Logger's `:backends` configuration                  | Logger's `:default_handler` configuration (v1.15)
[v1.19] | Passing a callback to `File.cp`/`File.cp_r`         | The `:on_conflict` option (v1.14)
[v1.18] | `<%#` in EEx                                        | `<%!--` (v1.14) or `<% #` (v1.0)
[v1.18] | `handle_text/2` callback in EEx                     | `handle_text/3` (v1.14)
[v1.18] | Returning 2-arity fun from `Enumerable.slice/1`     | Returning 3-arity (v1.14)
[v1.18] | Ranges with negative steps in `Range.new/2`         | Explicit steps in ranges (v1.11)
[v1.18] | `Tuple.append/2`                                    | `Tuple.insert_at/3` (v1.0)
[v1.18] | `mix cmd --app APP`                                 | `mix do --app APP` (v1.14)
[v1.18] | `List.zip/1`                                        | `Enum.zip/1` (v1.0)
[v1.18] | `Module.eval_quoted/3`                              | `Code.eval_quoted/3` (v1.0)
[v1.17] | Single-quoted charlists (`'foo'`)                   | `~c"foo"` (v1.0)
[v1.17] | `left..right` in patterns and guards                | `left..right//step` (v1.11)
[v1.17] | `ExUnit.Case.register_test/4`                       | `register_test/6` (v1.10)
[v1.17] | `:all` in `IO.read/2` and `IO.binread/2`            | `:eof` (v1.13)
[v1.16] | `~R/.../`                                           | `~r/.../` (v1.0)
[v1.16] | Ranges with negative steps in `Enum.slice/2`        | Explicit steps in ranges (v1.11)
[v1.16] | Ranges with negative steps in `String.slice/2`      | Explicit steps in ranges (v1.11)
[v1.15] | `Calendar.ISO.day_of_week/3`                        | `Calendar.ISO.day_of_week/4` (v1.11)
[v1.15] | `Exception.exception?/1`                            | `Kernel.is_exception/1` (v1.11)
[v1.15] | `Regex.regex?/1`                                    | `Kernel.is_struct/2` (`Kernel.is_struct(term, Regex)`) (v1.11)
[v1.15] | `Logger.warn/2`                                     | `Logger.warning/2` (v1.11)
[v1.14] | `use Bitwise`                                       | `import Bitwise` (v1.0)
[v1.14] | `~~~/1`                                             | `bnot/2` (v1.0)
[v1.14] | `Application.get_env/3` and similar in module body  | `Application.compile_env/3` (v1.10)
[v1.14] | Compiled patterns in `String.starts_with?/2`        | Pass a list of strings instead (v1.0)
[v1.14] | `Mix.Tasks.Xref.calls/1`                            | Compilation tracers (outlined in `Code`) (v1.10)
[v1.14] | `$levelpad` in Logger                               | *None*
[v1.14] | `<\|>` as a custom operator                         | Another custom operator (v1.0)
[v1.13] | `!` and `!=` in Version requirements                | `~>` or `>=` (v1.0)
[v1.13] | `Mix.Config`                                        | `Config` (v1.9)
[v1.13] | `:strip_beam` config to `mix escript.build`         | `:strip_beams` (v1.9)
[v1.13] | `Macro.to_string/2`                                 | `Macro.to_string/1` (v1.0)
[v1.13] | `System.get_pid/0`                                  | `System.pid/0` (v1.9)
[v1.12] | `^^^/2`                                             | `bxor/2` (v1.0)
[v1.12] | `@foo()` to read module attributes                  | Remove the parenthesis (v1.0)
[v1.12] | `use EEx.Engine`                                    | Explicitly delegate to EEx.Engine instead (v1.0)
[v1.12] | `:xref` compiler in Mix                             | Nothing (it always runs as part of the compiler now)
[v1.11] | `Mix.Project.compile/2`                             | `Mix.Task.run("compile", args)` (v1.0)
[v1.11] | `Supervisor.Spec.worker/3` and `Supervisor.Spec.supervisor/3` | The new child specs outlined in `Supervisor` (v1.5)
[v1.11] | `Supervisor.start_child/2` and `Supervisor.terminate_child/2` | `DynamicSupervisor` (v1.6)
[v1.11] | `System.stacktrace/1`                               | `__STACKTRACE__` in `try/catch/rescue` (v1.7)
[v1.10] | `Code.ensure_compiled?/1`                           | `Code.ensure_compiled/1` (v1.0)
[v1.10] | `Code.load_file/2`                                  | `Code.require_file/2` (v1.0) or `Code.compile_file/2` (v1.7)
[v1.10] | `Code.loaded_files/0`                               | `Code.required_files/0` (v1.7)
[v1.10] | `Code.unload_file/1`                                | `Code.unrequire_files/1` (v1.7)
[v1.10] | Passing non-chardata to `Logger.log/2`              | Explicitly convert to string with `to_string/1` (v1.0)
[v1.10] | `:compile_time_purge_level` in `Logger` app environment | `:compile_time_purge_matching` in `Logger` app environment (v1.7)
[v1.10] | `Supervisor.Spec.supervise/2`                       | The new child specs outlined in `Supervisor` (v1.5)
[v1.10] | `:simple_one_for_one` strategy in `Supervisor`      | `DynamicSupervisor` (v1.6)
[v1.10] | `:restart` and `:shutdown` in `Task.Supervisor.start_link/1` | `:restart` and `:shutdown` in `Task.Supervisor.start_child/3` (v1.6)
[v1.9]  | Enumerable keys in `Map.drop/2`, `Map.split/2`, and `Map.take/2` | Call `Enum.to_list/1` on the second argument before hand (v1.0)
[v1.9]  | `Mix.Project.load_paths/1`                          | `Mix.Project.compile_path/1` (v1.0)
[v1.9]  | Passing `:insert_replaced` to `String.replace/4`    | Use `:binary.replace/4` (v1.0)
[v1.8]  | Passing a non-empty list to `Collectable.into/1`    | `++/2` or `Keyword.merge/2` (v1.0)
[v1.8]  | Passing a non-empty list to `:into` in `for/1`      | `++/2` or `Keyword.merge/2` (v1.0)
[v1.8]  | Passing a non-empty list to `Enum.into/2`           | `++/2` or `Keyword.merge/2` (v1.0)
[v1.8]  | Time units in its plural form, such as: `:seconds`, `:milliseconds`, and the like | Use the singular form, such as: `:second`, `:millisecond`, and so on (v1.4)
[v1.8]  | `Inspect.Algebra.surround/3`                        | `Inspect.Algebra.concat/2` and `Inspect.Algebra.nest/2` (v1.0)
[v1.8]  | `Inspect.Algebra.surround_many/6`                   | `Inspect.Algebra.container_doc/6` (v1.6)
[v1.9]  | `--detached` in `Kernel.CLI`                        | `--erl "-detached"` (v1.0)
[v1.8]  | `Kernel.ParallelCompiler.files/2`                   | `Kernel.ParallelCompiler.compile/2` (v1.6)
[v1.8]  | `Kernel.ParallelCompiler.files_to_path/2`           | `Kernel.ParallelCompiler.compile_to_path/2` (v1.6)
[v1.8]  | `Kernel.ParallelRequire.files/2`                    | `Kernel.ParallelCompiler.require/2` (v1.6)
[v1.8]  | Returning `{:ok, contents}` or `:error` from `Mix.Compilers.Erlang.compile/6`'s callback | Return `{:ok, contents, warnings}` or `{:error, errors, warnings}` (v1.6)
[v1.8]  | `System.cwd/0` and `System.cwd!/0`                  | `File.cwd/0` and `File.cwd!/0` (v1.0)
[v1.7]  | `Code.get_docs/2`                                   | `Code.fetch_docs/1` (v1.7)
[v1.7]  | `Enum.chunk/2,3,4`                                  | `Enum.chunk_every/2` and [`Enum.chunk_every/3,4`](`Enum.chunk_every/4`) (v1.5)
[v1.7]  | Calling `super/1` in`GenServer` callbacks           | Implementing the behaviour explicitly without calling `super/1` (v1.0)
[v1.7]  | [`not left in right`](`in/2`)                | [`left not in right`](`in/2`) (v1.5)
[v1.7]  | `Registry.start_link/3`                             | `Registry.start_link/1` (v1.5)
[v1.7]  | `Stream.chunk/2,3,4`                                | `Stream.chunk_every/2` and [`Stream.chunk_every/3,4`](`Stream.chunk_every/4`) (v1.5)
[v1.6]  | `Enum.partition/2`                                  | `Enum.split_with/2` (v1.4)
[v1.6]  | `Macro.unescape_tokens/1,2`                         | Use `Enum.map/2` to traverse over the arguments (v1.0)
[v1.6]  | `Module.add_doc/6`                                  | [`@doc`](`Module`) module attribute (v1.0)
[v1.6]  | `Range.range?/1`                                    | Pattern match on [`_.._`](`../2`) (v1.0)
[v1.5]  | `()` to mean `nil`                                  | `nil` (v1.0)
[v1.5]  | `char_list/0` type                                  | `t:charlist/0` type (v1.3)
[v1.5]  | `Atom.to_char_list/1`                               | `Atom.to_charlist/1` (v1.3)
[v1.5]  | `Enum.filter_map/3`                                 | `Enum.filter/2` + `Enum.map/2` or `for/1` comprehensions (v1.0)
[v1.5]  | `Float.to_char_list/1`                              | `Float.to_charlist/1` (v1.3)
[v1.5]  | `GenEvent` module                                   | `Supervisor` and `GenServer` (v1.0);<br/>[`GenStage`](https://hex.pm/packages/gen_stage) (v1.3);<br/>[`:gen_event`](`:gen_event`) (Erlang/OTP 17)
[v1.5]  | `<%=` in middle and end expressions in `EEx`        | Use `<%` (`<%=` is allowed only in start expressions) (v1.0)
[v1.5]  | `:as_char_lists` value in `t:Inspect.Opts.t/0` type | `:as_charlists` value (v1.3)
[v1.5]  | `:char_lists` key in `t:Inspect.Opts.t/0` type      | `:charlists` key (v1.3)
[v1.5]  | `Integer.to_char_list/1,2`                          | `Integer.to_charlist/1` and `Integer.to_charlist/2` (v1.3)
[v1.5]  | `to_char_list/1`                                    | `to_charlist/1` (v1.3)
[v1.5]  | `List.Chars.to_char_list/1`                         | `List.Chars.to_charlist/1` (v1.3)
[v1.5]  | `@compile {:parse_transform, _}` in `Module`        | *None*
[v1.5]  | `Stream.filter_map/3`                               | `Stream.filter/2` + `Stream.map/2` (v1.0)
[v1.5]  | `String.ljust/3` and `String.rjust/3`               | Use `String.pad_leading/3` and `String.pad_trailing/3` with a binary padding (v1.3)
[v1.5]  | `String.lstrip/1` and `String.rstrip/1`             | `String.trim_leading/1` and `String.trim_trailing/1` (v1.3)
[v1.5]  | `String.lstrip/2` and `String.rstrip/2`             | Use `String.trim_leading/2` and `String.trim_trailing/2` with a binary as second argument (v1.3)
[v1.5]  | `String.strip/1` and `String.strip/2`               | `String.trim/1` and `String.trim/2` (v1.3)
[v1.5]  | `String.to_char_list/1`                             | `String.to_charlist/1` (v1.3)
[v1.4]  | Anonymous functions with no expression after `->`   | Use an expression or explicitly return `nil` (v1.0)
[v1.4]  | Support for making [private functions](`defp/2`) overridable | Use [public functions](`def/2`) (v1.0)
[v1.4]  | Variable used as function call                      | Use parentheses (v1.0)
[v1.4]  | `Access.key/1`                                      | `Access.key/2` (v1.3)
[v1.4]  | `Behaviour` module                                  | `@callback` module attribute (v1.0)
[v1.4]  | `Enum.uniq/2`                                       | `Enum.uniq_by/2` (v1.2)
[v1.4]  | `Float.to_char_list/2`                              | `:erlang.float_to_list/2` (Erlang/OTP 17)
[v1.4]  | `Float.to_string/2`                                 | `:erlang.float_to_binary/2` (Erlang/OTP 17)
[v1.4]  | `HashDict` module                                   | `Map` (v1.2)
[v1.4]  | `HashSet` module                                    | `MapSet` (v1.1)
[v1.4]  | `IEx.Helpers.import_file/2`                         | `IEx.Helpers.import_file_if_available/1` (v1.3)
[v1.4]  | `Mix.Utils.camelize/1`                              | `Macro.camelize/1` (v1.2)
[v1.4]  | `Mix.Utils.underscore/1`                            | `Macro.underscore/1` (v1.2)
[v1.4]  |  Multi-letter aliases in `OptionParser`             | Use single-letter aliases (v1.0)
[v1.4]  | `Set` module                                        | `MapSet` (v1.1)
[v1.4]  | `Stream.uniq/2`                                     | `Stream.uniq_by/2` (v1.2)
[v1.3]  | `\x{X*}` inside strings/sigils/charlists            | `\uXXXX` or `\u{X*}` (v1.1)
[v1.3]  | `Dict` module                                       | `Keyword` (v1.0) or `Map` (v1.2)
[v1.3]  | `:append_first` option in `defdelegate/2`           | Define the function explicitly (v1.0)
[v1.3]  | Map/dictionary as 2nd argument in `Enum.group_by/3` | `Enum.reduce/3` (v1.0)
[v1.3]  | `Keyword.size/1`                                    | `length/1` (v1.0)
[v1.3]  | `Map.size/1`                                        | `map_size/1` (v1.0)
[v1.3]  | `/r` option in `Regex`                              | `/U` (v1.1)
[v1.3]  | `Set` behaviour                                     | `MapSet` data structure (v1.1)
[v1.3]  | `String.valid_character?/1`                         | `String.valid?/1` (v1.0)
[v1.3]  | `Task.find/2`                                       | Use direct message matching (v1.0)
[v1.3]  | Non-map as 2nd argument in `URI.decode_query/2`     | Use a map (v1.0)
[v1.2]  | `Dict` behaviour                                    | `Map` and `Keyword` (v1.0)
[v1.1]  | `?\xHEX`                                            | `0xHEX` (v1.0)
[v1.1]  | `Access` protocol                                   | `Access` behaviour (v1.1)
[v1.1]  | `as: true \| false` in `alias/2` and `require/2`    | *None*

[v1.1]: https://github.com/elixir-lang/elixir/blob/v1.1/CHANGELOG.md#4-deprecations
[v1.2]: https://github.com/elixir-lang/elixir/blob/v1.2/CHANGELOG.md#changelog-for-elixir-v12
[v1.3]: https://github.com/elixir-lang/elixir/blob/v1.3/CHANGELOG.md#4-deprecations
[v1.4]: https://github.com/elixir-lang/elixir/blob/v1.4/CHANGELOG.md#4-deprecations
[v1.5]: https://github.com/elixir-lang/elixir/blob/v1.5/CHANGELOG.md#4-deprecations
[v1.6]: https://github.com/elixir-lang/elixir/blob/v1.6/CHANGELOG.md#4-deprecations
[v1.7]: https://github.com/elixir-lang/elixir/blob/v1.7/CHANGELOG.md#4-hard-deprecations
[v1.8]: https://github.com/elixir-lang/elixir/blob/v1.8/CHANGELOG.md#4-hard-deprecations
[v1.9]: https://github.com/elixir-lang/elixir/blob/v1.9/CHANGELOG.md#4-hard-deprecations
[v1.10]: https://github.com/elixir-lang/elixir/blob/v1.10/CHANGELOG.md#4-hard-deprecations
[v1.11]: https://github.com/elixir-lang/elixir/blob/v1.11/CHANGELOG.md#4-hard-deprecations
[v1.12]: https://github.com/elixir-lang/elixir/blob/v1.12/CHANGELOG.md#4-hard-deprecations
[v1.13]: https://github.com/elixir-lang/elixir/blob/v1.13/CHANGELOG.md#4-hard-deprecations
[v1.14]: https://github.com/elixir-lang/elixir/blob/v1.14/CHANGELOG.md#4-hard-deprecations
[v1.15]: https://github.com/elixir-lang/elixir/blob/v1.15/CHANGELOG.md#4-hard-deprecations
[v1.16]: https://github.com/elixir-lang/elixir/blob/v1.16/CHANGELOG.md#4-hard-deprecations
[v1.17]: https://github.com/elixir-lang/elixir/blob/v1.17/CHANGELOG.md#4-hard-deprecations
[v1.18]: https://github.com/elixir-lang/elixir/blob/v1.18/CHANGELOG.md#4-hard-deprecations
[v1.19]: https://github.com/elixir-lang/elixir/blob/v1.19/CHANGELOG.md#4-hard-deprecations
[v1.20]: https://github.com/elixir-lang/elixir/blob/main/CHANGELOG.md#4-hard-deprecations
