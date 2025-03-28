# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule Mix.ProjectStack do
  @moduledoc false

  use GenServer
  @name __MODULE__
  @timeout :infinity

  # compile.lock is not the best name, but the name is completely
  # opaque and we keep it for backwards compatibility (just in case).
  @manifest "compile.lock"

  @typep file :: binary
  @typep config :: keyword
  @typep project :: %{name: module, config: config, file: file}

  @spec start_link(keyword) :: {:ok, pid}
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  @spec on_clean_slate((-> result)) :: result when result: var
  def on_clean_slate(callback) do
    previous_state = update_state(fn state -> {state, initial_state()} end)

    try do
      callback.()
    after
      update_state(fn _ -> {:ok, previous_state} end)
    end
  end

  @spec clear_stack() :: :ok
  def clear_stack do
    update_state(fn _ -> {:ok, initial_state()} end)
  end

  @spec post_config(config) :: :ok
  def post_config(config) do
    update_state(fn {stack, post_config} ->
      {:ok, {stack, Keyword.merge(post_config, config)}}
    end)
  end

  @spec pop_post_config(atom) :: term
  def pop_post_config(key) do
    update_state(fn {stack, post_config} ->
      {value, post_config} = Keyword.pop(post_config, key)
      {value, {stack, post_config}}
    end)
  end

  @spec merge_config(config) :: :ok
  def merge_config(config) do
    update_stack(fn
      [h | t] -> {:ok, [update_in(h.config, &Keyword.merge(&1, config)) | t]}
      [] -> {:ok, []}
    end)
  end

  @spec on_recursing_root((-> result)) :: result when result: var
  def on_recursing_root(fun) do
    {top, file} =
      update_stack(fn stack ->
        {top, [mid | bottom]} = Enum.split_while(stack, &(not &1.recursing?))
        {{top, mid.file}, [%{mid | recursing?: false} | bottom]}
      end)

    try do
      File.cd!(Path.dirname(file), fun)
    after
      update_stack(fn [mid | bottom] ->
        {:ok, top ++ [%{mid | recursing?: true} | bottom]}
      end)
    end
  end

  @spec loaded_config([atom], [binary()]) :: :ok
  def loaded_config(apps, files) do
    update_stack(fn
      [%{config_apps: h_apps, config_files: h_files} = h | t] ->
        h = %{
          h
          | config_apps: apps ++ h_apps,
            config_files: files ++ h_files,
            config_mtime: nil
        }

        {:ok, [h | t]}

      [] ->
        {:ok, []}
    end)
  end

  # We include the year 2000 as a minimum value in case we
  # don't have any config files, which would return 0 and
  # then not trigger stale sources.
  @minimum_mtime 946_684_800

  @spec config_mtime() :: integer
  def config_mtime() do
    mtime_or_files =
      get_stack(fn
        [%{config_mtime: nil, config_files: files} | _] -> files
        [%{config_mtime: mtime} | _] -> mtime
        [] -> @minimum_mtime
      end)

    if is_list(mtime_or_files) do
      mtime =
        mtime_or_files
        |> Enum.map(&Mix.Utils.last_modified/1)
        |> Enum.max()
        |> max(@minimum_mtime)

      update_stack(fn [h | t] -> {mtime, [%{h | config_mtime: mtime} | t]} end)
    else
      mtime_or_files
    end
  end

  @spec reset_config_mtime() :: binary
  def reset_config_mtime() do
    update_stack(fn
      [h | t] -> {:ok, [%{h | config_mtime: nil} | t]}
      [] -> {:ok, []}
    end)

    @manifest
  end

  @spec config_apps() :: [atom]
  def config_apps() do
    get_stack(fn
      [h | _] -> h.config_apps
      [] -> []
    end)
  end

  @spec config_files() :: [binary]
  def config_files() do
    get_stack(fn
      [h | _] -> h.config_files
      [] -> []
    end)
  end

  @spec project_file() :: binary | nil
  def project_file() do
    get_stack(fn
      [h | _] -> h.file
      [] -> nil
    end)
  end

  @spec parent_umbrella_project_file() :: binary | nil
  def parent_umbrella_project_file() do
    get_stack(fn
      [_, h | _] -> if h.config[:apps_path], do: h.file, else: nil
      _ -> nil
    end)
  end

  @spec compile_env([term] | nil) :: [term] | nil
  def compile_env(compile_env) do
    update_stack(fn
      [h | t] -> {h.compile_env, [%{h | compile_env: compile_env} | t]}
      [] -> {nil, []}
    end)
  end

  @spec prepend_after_compiler(atom, fun) :: :ok
  def prepend_after_compiler(name, fun) do
    update_stack(fn
      [h | t] -> {:ok, [update_in(h.after_compiler[name], &[fun | &1 || []]) | t]}
      [] -> {:ok, []}
    end)
  end

  @spec pop_after_compiler(atom) :: [fun]
  def pop_after_compiler(name) do
    update_stack(fn
      [h | t] ->
        {value, h} = pop_in(h.after_compiler[name])
        {value || [], [h | t]}

      [] ->
        {[], []}
    end)
  end

  @spec pop() :: project | nil
  def pop do
    update_stack(fn
      [h | t] -> {project(h), t}
      [] -> {nil, []}
    end)
  end

  @spec peek() :: project | nil
  def peek do
    get_stack(fn
      [h | _] -> project(h)
      [] -> nil
    end)
  end

  @spec top_and_bottom() :: {project, project} | nil
  def top_and_bottom do
    get_stack(fn
      [h | _] = stack -> {project(h), project(List.last(stack))}
      [] -> nil
    end)
  end

  @spec printable_app_name() :: atom | nil
  def printable_app_name do
    update_stack(fn
      [] ->
        {nil, []}

      [%{io_done: true} | _] = stack ->
        {nil, stack}

      [h | t] ->
        h = %{h | io_done: true}
        t = Enum.map(t, &%{&1 | io_done: false})
        {h.config[:app], [h | t]}
    end)
  end

  @spec recur((-> result)) :: result when result: var
  def recur(fun) do
    update_stack(fn [h | t] -> {:ok, [%{h | recursing?: true} | t]} end)

    try do
      fun.()
    after
      update_stack(fn [h | t] -> {:ok, [%{h | recursing?: false} | t]} end)
    end
  end

  @spec recursing :: module | nil
  def recursing do
    get_stack(fn stack -> Enum.find_value(stack, &(&1.recursing? and &1.name)) end)
  end

  @spec push(module, config, file) :: :ok | {:error, file}
  def push(module, config, file) do
    update_state(fn {stack, post_config} ->
      if existing_file = find_project_named(module, stack) do
        {{:error, existing_file}, {stack, post_config}}
      else
        # Consider the first children to always have io_done
        # because we don't need to print anything unless another
        # project takes ahold of the shell.
        io_done? = stack == []
        config = Keyword.merge(config, post_config)
        manifest_file = Path.join(Mix.Project.manifest_path(config), @manifest)
        parent_files = peek_config_files(config[:inherit_parent_config_files], stack)

        project = %{
          name: module,
          config: config,
          file: file,
          pos: length(stack),
          recursing?: false,
          io_done: io_done?,
          config_apps: [],
          config_files: [manifest_file | parent_files],
          config_mtime: nil,
          after_compiler: %{},
          compile_env: nil
        }

        {:ok, {[project | stack], []}}
      end
    end)
  end

  defp peek_config_files(true, [%{config_files: files} | _]), do: files
  defp peek_config_files(_, _), do: []

  defp find_project_named(name, stack) do
    name &&
      Enum.find_value(stack, fn
        %{name: n, file: file} when n == name -> file
        %{} -> nil
      end)
  end

  defp project(h) do
    Map.take(h, [:name, :config, :file, :pos])
  end

  ## GenServer helpers and callbacks

  defp get_stack(fun) do
    GenServer.call(@name, {:get_stack, fun}, @timeout)
  end

  defp update_stack(fun) do
    GenServer.call(@name, {:update_stack, fun}, @timeout)
  end

  defp update_state(fun) do
    GenServer.call(@name, {:update_state, fun}, @timeout)
  end

  defp initial_state() do
    {[], []}
  end

  @impl true
  def init(:ok) do
    {:ok, initial_state()}
  end

  @impl true
  def handle_call({:get_stack, fun}, _from, {stack, post_config}) do
    {:reply, fun.(stack), {stack, post_config}}
  end

  @impl true
  def handle_call({:update_stack, fun}, _from, {stack, post_config}) do
    {reply, stack} = fun.(stack)
    {:reply, reply, {stack, post_config}}
  end

  @impl true
  def handle_call({:update_state, fun}, _from, state) do
    {reply, state} = fun.(state)
    {:reply, reply, state}
  end
end
