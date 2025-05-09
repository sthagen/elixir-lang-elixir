# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule Mix.Rebar do
  @moduledoc false

  # TODO: Remove on Elixir v1.22 because phx_new and other installers rely on it.
  @deprecated "Use env_rebar_path/1 instead"
  def global_rebar_cmd(manager) do
    env_rebar_path(manager)
  end

  @deprecated "Use local_rebar_path/1 instead"
  def local_rebar_cmd(manager) do
    local_rebar_path(manager)
  end

  @deprecated "Use rebar_args/2 or available?/1 instead"
  def rebar_cmd(manager) do
    global_rebar_cmd(manager) || local_rebar_cmd(manager)
  end

  @doc """
  Returns if Rebar is available or not.
  """
  def available?(manager) do
    env_rebar_path(manager) != nil or File.regular?(local_rebar_path(manager))
  end

  @doc """
  Receives a Rebar executable and returns how it must be invoked.

  It returns a result even if Rebar is not available.
  """
  def rebar_args(:rebar3, args) do
    rebar = env_rebar_path(:rebar3) || local_rebar_path(:rebar3)

    if match?({:win32, _}, :os.type()) and not String.ends_with?(rebar, ".cmd") do
      {"escript.exe", [rebar | args]}
    else
      {rebar, args}
    end
  end

  @doc """
  Returns the global rebar path.
  """
  def env_rebar_path(:rebar3) do
    System.get_env("MIX_REBAR3")
  end

  @doc """
  Returns the path supposed to host the local copy of `rebar`.

  The rebar3 installation is specific to the Elixir version and OTP release,
  in order to force updates when new Elixir versions come out.
  """
  def local_rebar_path(:rebar3) do
    [major, minor | _] = String.split(System.version(), ".")

    Path.join([
      Mix.Utils.mix_home(),
      "elixir",
      "#{major}-#{minor}-otp-#{System.otp_release()}",
      "rebar3"
    ])
  end

  @doc """
  Loads `rebar.config` and evaluates `rebar.config.script` if it
  exists in the given directory.
  """
  def load_config(dir) do
    config_path = Path.join(dir, "rebar.config")
    script_path = Path.join(dir, "rebar.config.script")

    config =
      case :file.consult(config_path) do
        {:ok, config} ->
          config

        {:error, :enoent} ->
          []

        {:error, error} ->
          reason = :file.format_error(error)
          Mix.raise("Error consulting Rebar config #{inspect(config_path)}: #{reason}")
      end

    if File.exists?(script_path) do
      eval_script(script_path, config)
    else
      config
    end
  end

  @doc """
  Serializes a Rebar config to a term file.
  """
  def serialize_config(config) do
    Enum.map(config, &[:io_lib.print(&1) | ".\n"])
  end

  @doc """
  Updates Rebar configuration to be more suitable for dependencies.
  """
  def dependency_config(config) do
    Enum.flat_map(config, fn
      {:erl_opts, opts} ->
        [{:erl_opts, List.delete(opts, :warnings_as_errors)}]

      {:project_plugins, _} ->
        []

      other ->
        [other]
    end)
  end

  @doc """
  Parses the dependencies in given `rebar.config` to Mix's dependency format.
  """
  def deps(config) do
    # We don't have to handle Rebar3 profiles because dependencies
    # are always in the default profile which cannot be customized
    if deps = config[:deps] do
      Enum.map(deps, &parse_dep/1)
    else
      []
    end
  end

  # Translate a Rebar dependency declaration to a Mix declaration
  # From http://www.rebar3.org/docs/dependencies#section-declaring-dependencies
  defp parse_dep(app) when is_atom(app) do
    {app, override: true}
  end

  defp parse_dep({app, req}) when is_list(req) do
    {app, List.to_string(req), override: true}
  end

  defp parse_dep({app, source}) when is_tuple(source) do
    parse_dep({app, nil, source, []})
  end

  defp parse_dep({app, req, source}) do
    parse_dep({app, req, source, []})
  end

  defp parse_dep({app, req, source, opts}) do
    source = parse_source(source)
    compile = if :proplists.get_value(:raw, opts, false), do: [compile: false], else: []
    opts = [override: true] ++ source ++ compile

    if req do
      {app, compile_req(req), opts}
    else
      {app, opts}
    end
  end

  defp parse_source({:pkg, pkg}) do
    [hex: pkg]
  end

  defp parse_source(source) do
    [scm, url | source] = Tuple.to_list(source)

    {scm, additional_opts} =
      case {scm, source} do
        {:git_subdir, [_, sparse_dir | _]} -> {:git, [sparse: sparse_dir]}
        {_, _} -> {:git, []}
      end

    ref =
      case source do
        ["" | _] -> [branch: "HEAD"]
        [{:branch, branch} | _] -> [branch: to_string(branch)]
        [{:tag, tag} | _] -> [tag: to_string(tag)]
        [{:ref, ref} | _] -> [ref: to_string(ref)]
        [ref | _] -> [ref: to_string(ref)]
        _ -> []
      end

    [{scm, to_string(url)}] ++ ref ++ additional_opts
  end

  defp compile_req(req) do
    req = List.to_string(req)

    case Version.parse_requirement(req) do
      {:ok, _} ->
        req

      :error ->
        case Regex.compile(req) do
          {:ok, re} ->
            re

          {:error, reason} ->
            Mix.raise("Unable to compile version regular expression: #{inspect(req)}, #{reason}")
        end
    end
  end

  defp eval_script(script_path, config) do
    script = String.to_charlist(Path.basename(script_path))

    result =
      File.cd!(Path.dirname(script_path), fn ->
        :file.script(script, eval_binds(CONFIG: config, SCRIPT: script))
      end)

    case result do
      {:ok, config} ->
        config

      {:error, error} ->
        reason = :file.format_error(error)
        Mix.shell().error("Error evaluating Rebar config script #{script_path}:#{reason}")

        Mix.shell().error(
          "Any dependencies defined in the script won't be available " <>
            "unless you add them to your Mix project"
        )

        config
    end
  end

  defp eval_binds(binds) do
    Enum.reduce(binds, :erl_eval.new_bindings(), fn {k, v}, binds ->
      :erl_eval.add_binding(k, v, binds)
    end)
  end

  @doc """
  Applies the given overrides for app config.
  """
  def apply_overrides(app, config, overrides) do
    # Inefficient. We want the order we get here though.
    config =
      Enum.reduce(overrides, config, fn
        {:override, overrides}, config ->
          Enum.reduce(overrides, config, fn {key, value}, config ->
            Keyword.put(config, key, value)
          end)

        _, config ->
          config
      end)

    config =
      Enum.reduce(overrides, config, fn
        {:override, ^app, overrides}, config ->
          Enum.reduce(overrides, config, fn {key, value}, config ->
            Keyword.put(config, key, value)
          end)

        _, config ->
          config
      end)

    config =
      Enum.reduce(overrides, config, fn
        {:add, ^app, overrides}, config ->
          Enum.reduce(overrides, config, fn {key, value}, config ->
            old_value = Keyword.get(config, key, [])
            Keyword.put(config, key, value ++ old_value)
          end)

        _, config ->
          config
      end)

    Keyword.update(config, :overrides, overrides, &(overrides ++ &1))
  end
end
