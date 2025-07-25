# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

defmodule Mix.Project do
  @moduledoc """
  Defines and manipulates Mix projects.

  A Mix project is defined by calling `use Mix.Project` in a module, usually
  placed in `mix.exs`:

      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            version: "1.0.0"
          ]
        end
      end

  > #### `use Mix.Project` {: .info}
  >
  > When you `use Mix.Project`, it notifies Mix that a new project
  > has been defined, so all Mix tasks use your module as a starting
  > point.

  ## Configuration

  In order to configure Mix, the module that calls `use Mix.Project` should export
  a `project/0` function that returns a keyword list representing configuration
  for the project.

  This configuration can be read using `Mix.Project.config/0`. Note that
  `config/0` won't fail if a project is not defined; this allows many Mix tasks
  to work without a project.

  If a task requires a project to be defined or needs to access a
  special function within the project, the task can call `Mix.Project.get!/0`
  which fails with `Mix.NoProjectError` in the case a project is not
  defined.

  There isn't a comprehensive list of all the options that can be returned by
  `project/0` since many Mix tasks define their own options that they read from
  this configuration. For example, look at the "Configuration" section in the
  documentation for the `Mix.Tasks.Compile` task.

  These are a few options that are not used by just one Mix task (and will thus
  be documented here):

    * `:build_per_environment` - if `true`, builds will be *per-environment*. If
      `false`, builds will go in `_build/shared` regardless of the Mix
      environment. Defaults to `true`.

    * `:aliases` - a list of task aliases. For more information, check out the
      "Aliases" section in the documentation for the `Mix` module. Defaults to
      `[]`.

    * `:config_path` - a string representing the path of the main config
      file. See `config_files/0` for more information. Defaults to
      `"config/config.exs"`.

    * `:deps` - a list of dependencies of this project. Refer to the
      documentation for the `Mix.Tasks.Deps` task for more information. Defaults
      to `[]`.

    * `:deps_path` - directory where dependencies are stored. Also see
      `deps_path/1`. Defaults to `"deps"`.

    * `:lockfile` - the name of the lockfile used by the `mix deps.*` family of
      tasks. Defaults to `"mix.lock"`.

  Mix tasks may require their own configuration inside `def project`. For example,
  check the `Mix.Tasks.Compile` task and all the specific compiler tasks
  (such as `Mix.Tasks.Compile.Elixir` or `Mix.Tasks.Compile.Erlang`).

  Note that different tasks may share the same configuration option. For example,
  the `:erlc_paths` configuration is used by `mix compile.erlang`, `mix compile.yecc`,
  and other tasks.

  > #### Keep `project/0` fast {: .warning}
  >
  > `project/0` is called whenever your `mix.exs` is loaded, so heavy
  > computation should be avoided. If a task requires a potentially complex
  > configuration value, it should allow its configuration to be set to an
  > anonymous function or similar, so that it can be invoked only when
  > needed by the task itself.

  ## CLI configuration

  Mix is most often invoked from the command line. For this purpose, you may define
  a specific `cli/0` function which customizes default values when executed from
  the CLI. For example:

      def cli do
        [
          default_task: "phx.server",
          preferred_envs: [docs: :docs]
        ]
      end

  The example above sets the default task (used by `iex -S mix` and `mix`) to
  `phx.server`. It also sets the default environment for the "mix docs" task to
  be "docs".

  The following CLI configuration are available:

    * `:default_env` - the default environment to use when none is given
      and `MIX_ENV` is not set

    * `:default_target` - the default target to use when none is given
      and `MIX_TARGET` is not set

    * `:default_task` - the default task to invoke when none is given

    * `:preferred_envs` - a keyword list of `{task, env}` tuples where `task`
      is the task name as an atom (for example, `:"deps.get"`) and `env` is the
      preferred environment (for example, `:test`)

    * `:preferred_targets` - a keyword list of `{task, target}` tuples where
      `task` is the task name as an atom (for example, `:test`) and `target`
      is the preferred target (for example, `:host`)

  ## Erlang projects

  Mix can be used to manage Erlang projects that don't have any Elixir code. To
  ensure Mix tasks work correctly for an Erlang project, `language: :erlang` has
  to be part of the configuration returned by `project/0`. This setting also
  makes sure Elixir is not added as a dependency to the generated `.app` file or
  to the escript generated with `mix escript.build`, and so on.

  ## Umbrella projects

  Umbrella projects are a convenience to help you organize and manage multiple
  applications. While it provides a degree of separation between applications,
  those applications are not fully decoupled, as they share the same configuration
  and the same dependencies.

  In an umbrella project, you have an `apps/` folder where you store each application.
  Then, instead of each app in the umbrella having its own configuration, build cache,
  lockfile and so, they all point to the parent project by specifying the following
  configuration in their `mix.exs`:

      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",

  The pattern of keeping multiple applications in the same repository is known as
  [monorepo](https://en.wikipedia.org/wiki/Monorepo). Umbrella projects maximize
  this pattern by providing conveniences to compile, test and run multiple
  applications at once. When an umbrella application needs to depend on another
  one, it can be done by passing the `in_umbrella: true` option to your dependency.
  If an umbrella application `:foo` depends on its sibling `:bar`, you can specify
  this dependency in `foo`'s `mix.exs` file as:

      {:bar, in_umbrella: true}

  ### Undoing umbrellas

  Using umbrella projects can impact how you design and write your software and,
  as time passes, they may turn out to be the wrong choice.
  If you find yourself in a position where you want to use different configurations
  in each application for the same dependency or use different dependency versions,
  then it is likely your codebase has grown beyond what umbrellas can provide.

  If you find yourself in this situation, you have two options:

    1. Convert everything into a single Mix project, which can be done in steps.
       First move all files in `lib`, `test`, `priv`, and friends into a single
       application, while still keeping the overall umbrella structure and
       `mix.exs` files. For example, if your umbrellas has three applications,
       `foo`, `bar` and `baz`, where `baz` depends on both `foo` and `bar`,
       move all source to `baz`. Then remove `foo` and `bar` one by one,
       updating any configuration and removing references to the `:foo` and
      `:bar` application names. Until you have only a single application.

    2. Remove umbrella structure while keeping them as distinct applications.
       This is done by moving applications outside of the umbrella
       project's `apps/` directory and updating the projects' `mix.exs` files
       to no longer set the `build_path`, `config_path`, `deps_path`, and
       `lockfile` configurations, guaranteeing each of them have their own
       build and dependency structure.

  Keep in mind that umbrellas are one of many options for managing private
  packages within your organization. You might:

    1. Have multiple directories inside the same repository and using `:path`
       dependencies (which is essentially the monorepo pattern)
    2. Use private Git repositories and Mix' ability to fetch Git dependencies
    3. Publishing packages to a private [Hex.pm](https://hex.pm/) organization

  ## Invoking this module

  This module contains many functions that return project information and
  metadata. However, since Mix is not included nor configured during releases,
  we recommend using the functions in this module only inside Mix tasks.
  If you need to configure your own app, consider using the application
  environment instead. For example, don't do this:

      def some_config do
        Mix.Project.config()[:some_config]
      end

  Nor this:

      @some_config Mix.Project.config()[:some_config]

  Instead, do this:

      def some_config do
        Application.get_env(:my_app, :some_config)
      end

  Or this:

      @some_config Application.compile_env(:my_app, :some_config)

  """

  @type build_structure_opts :: [
          symlink_ebin: boolean(),
          source: String.t()
        ]

  @typedoc """
  Options for dependency traversal functions.

  These options control how dependency trees are traversed and filtered
  in functions like `deps_scms/1`, `deps_paths/1`, and `deps_tree/1`.
  """
  @type deps_traversal_opts :: [
          depth: pos_integer(),
          parents: [atom()]
        ]

  @doc false
  defmacro __using__(_) do
    quote do
      @after_compile Mix.Project
    end
  end

  # Invoked after each Mix.Project is compiled.
  @doc false
  def __after_compile__(env, _binary) do
    push(env.module, env.file)
  end

  # Push a project onto the project stack.
  # Only the top of the stack can be accessed.
  @doc false
  def push(module, file \\ nil, app \\ nil) when is_atom(module) do
    file =
      cond do
        file != nil -> file
        source = module && module.module_info(:compile)[:source] -> List.to_string(source)
        true -> "nofile"
      end

    case Mix.ProjectStack.push(module, push_config(module, app), file) do
      :ok ->
        :ok

      {:error, other} when is_binary(other) ->
        Mix.raise(
          "Trying to load #{inspect(module)} from #{inspect(file)}" <>
            " but another project with the same name was already defined at #{inspect(other)}"
        )
    end
  end

  @preferred_envs [test: :test, "test.coverage": :test]

  defp push_config(module, app) do
    with {state_loader, task} <- Mix.ProjectStack.pop_post_config(:state_loader) do
      config =
        if function_exported?(module, state_loader, 0),
          do: apply(module, state_loader, []),
          else: []

      task = String.to_atom(task || config[:default_task] || "run")

      if !System.get_env("MIX_ENV") do
        if env = config[:preferred_envs][task] || @preferred_envs[task] || config[:default_env] do
          Mix.env(env)
        end
      end

      if !System.get_env("MIX_TARGET") do
        if target = config[:preferred_targets][task] || config[:default_target] do
          Mix.target(target)
        end
      end
    end

    ([app: app] ++ default_config())
    |> Keyword.merge(get_project_config(module))
  end

  # Pops a project from the stack.
  @doc false
  def pop do
    Mix.ProjectStack.pop()
  end

  # The configuration that is pushed down to dependencies.
  @doc false
  def deps_config(config \\ config()) do
    [
      consolidate_protocols: false,
      consolidation_path: consolidation_path(config),
      deps_path: deps_path(config),
      deps_build_path: build_path(config),
      lockfile: Path.expand(config[:lockfile])
    ] ++ Keyword.take(config, [:build_embedded, :build_per_environment, :prune_code_paths])
  end

  @doc """
  Retrieves the current project if there is one.

  If there is no current project, `nil` is returned. This
  may happen in cases there is no `mix.exs` in the current
  directory.

  If you expect a project to be defined, i.e., it is a
  requirement of the current task, you should call
  `get!/0` instead.
  """
  @spec get() :: module | nil
  def get do
    case Mix.ProjectStack.peek() do
      %{name: name} -> name
      _ -> nil
    end
  end

  @doc """
  Same as `get/0`, but raises an exception if there is no current project.

  This is usually called by tasks that need additional
  functions on the project to be defined. Since such
  tasks usually depend on a project being defined, this
  function raises a `Mix.NoProjectError` exception in
  case no project is available.
  """
  @spec get!() :: module
  def get! do
    get() || raise Mix.NoProjectError, []
  end

  @doc """
  Returns the path to the file that defines the current project.

  The majority of the time, it will point to a `mix.exs` file.
  Returns `nil` if not inside a project.
  """
  @doc since: "1.13.0"
  @spec project_file() :: binary | nil
  defdelegate project_file(), to: Mix.ProjectStack

  @doc """
  Returns the path to the file that defines the parent umbrella project, if one.

  The majority of the time, it will point to a `mix.exs` file.
  Returns `nil` if not inside a project or not inside an umbrella.
  """
  @doc since: "1.15.0"
  @spec parent_umbrella_project_file() :: binary | nil
  defdelegate parent_umbrella_project_file(), to: Mix.ProjectStack

  @doc """
  Returns the project configuration.

  If there is no project defined, it still returns a keyword
  list with default values. This allows many Mix tasks to work
  without the need for an underlying project.

  Note this configuration is cached once the project is
  pushed onto the stack. Calling it multiple times won't
  cause it to be recomputed.

  Do not use `Mix.Project.config/0` to find the runtime configuration.
  Use it only to configure aspects of your project (like
  compilation directories) and not your application runtime.
  """
  @spec config() :: keyword
  def config do
    case Mix.ProjectStack.peek() do
      %{config: config} -> config
      _ -> default_config()
    end
  end

  @doc """
  Returns a list of project configuration files for this project.

  This function is usually used in compilation tasks to trigger
  a full recompilation whenever such configuration files change.

  It returns the lock manifest, and all config files in the `config`
  directory that do not start with a leading period (for example,
  `.my_config.exs`).

  Note: before Elixir v1.13.0, the `mix.exs` file was also included
  as a config file, but since then it has been moved to its own
  function called `project_file/0`.
  """
  @spec config_files() :: [Path.t()]
  def config_files do
    Mix.ProjectStack.config_files()
  end

  @doc """
  Returns the latest modification time from config files.

  This function is usually used in compilation tasks to trigger
  a full recompilation whenever such configuration files change.
  For this reason, the mtime is cached to avoid file system lookups.

  However, for effective used of this function, you must avoid
  comparing source files with the `config_mtime` itself. Instead,
  store the previous `config_mtime` and compare it with the new
  `config_mtime` in order to detect if something is stale.

  Note: before Elixir v1.13.0, the `mix.exs` file was also included
  in the mtimes, but not anymore. You can compute its modification
  date by calling `project_file/0`.
  """
  @doc since: "1.7.0"
  @spec config_mtime() :: posix_mtime when posix_mtime: integer()
  def config_mtime do
    Mix.ProjectStack.config_mtime()
  end

  @doc """
  Returns `true` if `config` is the configuration for an umbrella project.

  When called with no arguments, tells whether the current project is
  an umbrella project.
  """
  @spec umbrella?(keyword) :: boolean
  def umbrella?(config \\ config()) do
    config[:apps_path] != nil
  end

  @doc """
  Returns a map with the umbrella child applications paths.

  These paths are based on the `:apps_path` and `:apps` configurations.

  If the given project configuration identifies an umbrella project, the return
  value is a map of `app => path` where `app` is a child app of the umbrella and
  `path` is its path relative to the root of the umbrella project.

  If the given project configuration does not identify an umbrella project,
  `nil` is returned.

  ## Examples

      Mix.Project.apps_paths()
      #=> %{my_app1: "apps/my_app1", my_app2: "apps/my_app2"}

  """
  @doc since: "1.4.0"
  @spec apps_paths(keyword) :: %{optional(atom) => Path.t()} | nil
  def apps_paths(config \\ config()) do
    if apps_path = config[:apps_path] do
      key = {:apps_paths, Mix.Project.get!()}

      if cache = Mix.State.read_cache(key) do
        cache
      else
        cache = config[:apps] |> umbrella_apps(apps_path) |> to_apps_paths(apps_path)
        Mix.State.write_cache(key, cache)
      end
    end
  end

  defp umbrella_apps(nil, apps_path) do
    case File.ls(apps_path) do
      {:ok, apps} -> Enum.map(apps, &String.to_atom/1)
      {:error, _} -> []
    end
  end

  defp umbrella_apps(apps, _apps_path) when is_list(apps) do
    apps
  end

  defp to_apps_paths(apps, apps_path) do
    for app <- apps,
        path = path_with_mix_exs_otherwise_warn(app, apps_path),
        do: {app, path},
        into: %{}
  end

  defp path_with_mix_exs_otherwise_warn(app, apps_path) do
    path = Path.join(apps_path, Atom.to_string(app))

    cond do
      File.regular?(Path.join(path, "mix.exs")) ->
        path

      File.dir?(path) ->
        Mix.shell().error(
          "warning: path #{inspect(Path.relative_to_cwd(path))} is a directory but " <>
            "it has no mix.exs. Mix won't consider this directory as part of your " <>
            "umbrella application. Please add a \"mix.exs\" or set the \":apps\" key " <>
            "in your umbrella configuration with all relevant apps names as atoms"
        )

        nil

      true ->
        # If it is a stray file, we just ignore it.
        nil
    end
  end

  @doc ~S"""
  Runs the given `fun` inside the given project.

  This function changes the current working directory and
  loads the project at the given directory onto the project
  stack.

  A `post_config` can be passed that will be merged into
  the project configuration.

  `fun` is called with the module name of the given `Mix.Project`.
  The return value of this function is the return value of `fun`.

  ## Examples

      Mix.Project.in_project(:my_app, "/path/to/my_app", fn module ->
        "Mix project is: #{inspect(module)}"
      end)
      #=> "Mix project is: MyApp.MixProject"

  """
  @spec in_project(atom, Path.t(), keyword, (module -> result)) :: result when result: term
  def in_project(app, path, post_config \\ [], fun)

  def in_project(app, ".", post_config, fun) when is_atom(app) do
    cached =
      try do
        load_project(app, post_config)
      rescue
        any ->
          Mix.shell().error("Error while loading project #{inspect(app)} at #{File.cwd!()}")
          reraise any, __STACKTRACE__
      end

    try do
      fun.(cached)
    after
      Mix.Project.pop()
    end
  end

  def in_project(app, path, post_config, fun) when is_atom(app) do
    File.cd!(path, fn ->
      in_project(app, ".", post_config, fun)
    end)
  end

  @doc """
  Returns the path where dependencies are stored for the given project.

  If no configuration is given, the one for the current project is used.

  The returned path will be expanded.

  ## Examples

      Mix.Project.deps_path()
      #=> "/path/to/project/deps"

  """
  @spec deps_path(keyword) :: Path.t()
  def deps_path(config \\ config()) do
    dir = System.get_env("MIX_DEPS_PATH") || config[:deps_path]
    Path.expand(dir)
  end

  @doc """
  Returns all dependencies app names.

  The order they are returned is guaranteed to be sorted
  for proper dependency resolution. For example, if A
  depends on B, then B will listed before A.
  """
  @doc since: "1.11.0"
  @spec deps_apps() :: [atom()]
  def deps_apps() do
    Mix.Dep.cached() |> Enum.map(& &1.app)
  end

  @doc """
  Returns the SCMs of all dependencies as a map.

  See `Mix.SCM` module documentation to learn more about SCMs.

  ## Options

    * `:depth` - only returns dependencies to the depth level,
      a depth of `1` will only return top-level dependencies
    * `:parents` - starts the dependency traversal from the
      given parents instead of the application root

  ## Examples

      Mix.Project.deps_scms()
      #=> %{foo: Mix.SCM.Path, bar: Mix.SCM.Git}

  """
  @doc since: "1.10.0"
  @spec deps_scms(deps_traversal_opts) :: %{optional(atom) => Mix.SCM.t()}
  def deps_scms(opts \\ []) when is_list(opts) do
    traverse_deps(opts, fn %{scm: scm} -> scm end)
  end

  @doc """
  Returns the full path of all dependencies as a map.

  ## Options

    * `:depth` - only returns dependencies to the depth level,
      a depth of `1` will only return top-level dependencies
    * `:parents` - starts the dependency traversal from the
      given parents instead of the application root

  ## Examples

      Mix.Project.deps_paths()
      #=> %{foo: "deps/foo", bar: "custom/path/dep"}

  """
  @spec deps_paths(deps_traversal_opts) :: %{optional(atom) => Path.t()}
  def deps_paths(opts \\ []) when is_list(opts) do
    traverse_deps(opts, fn %{opts: opts} -> opts[:dest] end)
  end

  @doc """
  Returns the dependencies of all dependencies as a map.

  ## Options

    * `:depth` - only returns dependencies to the depth level,
      a depth of `1` will only return top-level dependencies
    * `:parents` - starts the dependency traversal from the
      given parents instead of the application root

  ## Examples

      Mix.Project.deps_tree()
      #=> %{foo: [:bar, :baz], bar: [], baz: []}

  """
  @doc since: "1.15.0"
  @spec deps_tree(deps_traversal_opts) :: %{optional(atom) => [atom]}
  def deps_tree(opts \\ []) when is_list(opts) do
    traverse_deps(opts, fn %{deps: deps} -> Enum.map(deps, & &1.app) end)
  end

  defp traverse_deps(opts, fun) do
    all_deps = Mix.Dep.cached()
    parents = opts[:parents]
    depth = opts[:depth]

    if parents || depth do
      parent_filter = if parents, do: &(&1.app in parents), else: & &1.top_level

      all_deps
      |> Enum.filter(parent_filter)
      |> traverse_deps_map(fun)
      |> traverse_deps_depth(all_deps, fun, 1, depth || :infinity)
    else
      traverse_deps_map(all_deps, fun)
    end
  end

  defp traverse_deps_map(deps, fun) do
    for %{app: app} = dep <- deps, do: {app, fun.(dep)}, into: %{}
  end

  defp traverse_deps_depth(deps, _all_deps, _fun, depth, depth) do
    deps
  end

  defp traverse_deps_depth(parents, all_deps, fun, depth, target_depth) do
    children =
      for parent_dep <- all_deps,
          Map.has_key?(parents, parent_dep.app),
          %{app: app} = dep <- parent_dep.deps,
          do: {app, fun.(dep)},
          into: %{}

    case Map.merge(parents, children) do
      ^parents -> parents
      new_parents -> traverse_deps_depth(new_parents, all_deps, fun, depth + 1, target_depth)
    end
  end

  @doc """
  Clears the dependency for the current environment.

  Useful when dependencies need to be reloaded due to change of global state.

  For example, Nerves uses this function to force all dependencies to be
  reloaded after it updates the system environment. It goes roughly like
  this:

    1. Nerves fetches all dependencies and looks for the system specific deps
    2. Once the system specific dep is found, it loads it alongside env vars
    3. Nerves then clears the cache, forcing dependencies to be loaded again
    4. Dependencies are loaded again, now with an updated env environment

  """
  @doc since: "1.7.0"
  @spec clear_deps_cache() :: :ok
  def clear_deps_cache() do
    Mix.Dep.clear_cached()
    :ok
  end

  @doc """
  Returns the build path for the given project.

  The build path is built based on the `:build_path` configuration
  (which defaults to `"_build"`) and a subdirectory. The subdirectory
  is built based on two factors:

    * If `:build_per_environment` is set (the default), the subdirectory
      is the value of `Mix.env/0` (which can be set via `MIX_ENV`).
      Otherwise it is set to "shared".

    * If `Mix.target/0` is set (often via the `MIX_TARGET` environment
      variable), it will be used as a prefix to the subdirectory.

  The behaviour of this function can be modified by two environment
  variables, `MIX_BUILD_ROOT` and `MIX_BUILD_PATH`, see [the Mix
  documentation for more information](Mix.html#environment-variables).

  > #### Naming differences {: .info}
  >
  > Ideally the configuration option `:build_path` would be called
  > `:build_root`, as it only sets the root component of the build
  > path but not the subdirectory. However, its name is preserved
  > for backwards compatibility.

  ## Examples

      Mix.Project.build_path()
      #=> "/path/to/project/_build/shared"

  If `:build_per_environment` is set to `true`, it will create a new build per
  environment:

      Mix.env()
      #=> :dev
      Mix.Project.build_path()
      #=> "/path/to/project/_build/dev"

  """
  @spec build_path(keyword) :: Path.t()
  def build_path(config \\ config()) do
    System.get_env("MIX_BUILD_PATH") || config[:deps_build_path] || do_build_path(config)
  end

  defp do_build_path(config) do
    dir = System.get_env("MIX_BUILD_ROOT") || config[:build_path] || "_build"
    subdir = build_target() <> build_per_environment(config)
    Path.expand(dir <> "/" <> subdir)
  end

  defp build_target do
    case Mix.target() do
      :host -> ""
      other -> "#{other}_"
    end
  end

  defp build_per_environment(config) do
    case config[:build_per_environment] do
      true ->
        Atom.to_string(Mix.env())

      false ->
        "shared"

      other ->
        Mix.raise("The :build_per_environment option should be a boolean, got: #{inspect(other)}")
    end
  end

  @doc """
  Returns the path where manifests are stored.

  By default they are stored in the app path inside
  the build directory. Umbrella applications have
  the manifest path set to the root of the build directory.
  Directories may be changed in future releases.

  The returned path will be expanded.

  ## Examples

  If your project defines the app `my_app`:

      Mix.Project.manifest_path()
      #=> "/path/to/project/_build/shared/lib/my_app/.mix"

  """
  @spec manifest_path(keyword) :: Path.t()
  def manifest_path(config \\ config()) do
    app_path =
      config[:deps_app_path] ||
        if app = config[:app] do
          Path.join([build_path(config), "lib", Atom.to_string(app)])
        else
          build_path(config)
        end

    Path.join(app_path, ".mix")
  end

  @doc """
  Returns the application path inside the build.

  The returned path will be expanded.

  ## Examples

  If your project defines the app `my_app`:

      Mix.Project.app_path()
      #=> "/path/to/project/_build/shared/lib/my_app"

  """
  @spec app_path(keyword) :: Path.t()
  def app_path(config \\ config()) do
    config[:deps_app_path] ||
      cond do
        app = config[:app] ->
          Path.join([build_path(config), "lib", Atom.to_string(app)])

        config[:apps_path] ->
          raise "trying to access Mix.Project.app_path/1 for an umbrella project but umbrellas have no app"

        true ->
          Mix.raise(
            "Cannot access build without an application name, " <>
              "please ensure you are in a directory with a mix.exs file and it defines " <>
              "an :app name under the project configuration"
          )
      end
  end

  @doc """
  Returns the paths the given project compiles to.

  If no configuration is given, the one for the current project will be used.

  The returned path will be expanded.

  ## Examples

  If your project defines the app `my_app`:

      Mix.Project.compile_path()
      #=> "/path/to/project/_build/dev/lib/my_app/ebin"

  """
  @spec compile_path(keyword) :: Path.t()
  def compile_path(config \\ config()) do
    Path.join(app_path(config), "ebin")
  end

  @doc """
  Returns the path where protocol consolidations are stored.

  The returned path will be expanded.

  ## Examples

  If your project defines the app `my_app`:

      Mix.Project.consolidation_path()
      #=> "/path/to/project/_build/dev/lib/my_app/consolidated"

  Inside umbrellas:

      Mix.Project.consolidation_path()
      #=> "/path/to/project/_build/dev/consolidated"

  """
  @spec consolidation_path(keyword) :: Path.t()
  def consolidation_path(config \\ config()) do
    config[:consolidation_path] ||
      if umbrella?(config) do
        Path.join(build_path(config), "consolidated")
      else
        Path.join(app_path(config), "consolidated")
      end
  end

  @doc false
  @deprecated "Use Mix.Task.run(\"compile\", args) instead"
  def compile(args, _config \\ []) do
    Mix.Task.run("compile", args)
  end

  @doc """
  Builds the project structure for the given application.

  ## Options

    * `:symlink_ebin` - symlink ebin instead of copying it

    * `:source` - the source directory to copy from.
      Defaults to the current working directory.

  """
  @spec build_structure(keyword, build_structure_opts) :: :ok
  def build_structure(config \\ config(), opts \\ []) do
    source = opts[:source] || File.cwd!()
    target = app_path(config)
    File.mkdir_p!(target)
    target_ebin = Path.join(target, "ebin")

    _ =
      cond do
        opts[:symlink_ebin] ->
          _ = Mix.Utils.symlink_or_copy(Path.join(source, "ebin"), target_ebin)

        match?({:ok, _}, :file.read_link(target_ebin)) ->
          _ = File.rm_rf!(target_ebin)
          File.mkdir_p!(target_ebin)

        true ->
          File.mkdir_p!(target_ebin)
      end

    for dir <- ~w(include priv) do
      Mix.Utils.symlink_or_copy(Path.join(source, dir), Path.join(target, dir))
    end

    :ok
  end

  @doc """
  Ensures the project structure for the given project exists.

  In case it does exist, it is a no-op. Otherwise, it is built.

  `opts` are the same options that can be passed to `build_structure/2`.
  """
  @spec ensure_structure(keyword, build_structure_opts) :: :ok
  def ensure_structure(config \\ config(), opts \\ []) do
    if File.exists?(app_path(config)) do
      :ok
    else
      build_structure(config, opts)
    end
  end

  @deprecated "Use Mix.Project.compile_path/1 instead"
  def load_paths(config \\ config()) do
    if umbrella?(config) do
      []
    else
      [compile_path(config)]
    end
  end

  @doc """
  Acquires a lock on the project build path and runs the given function.

  When another process (across all OS processes) is holding the lock,
  a message is printed and this call blocks until the lock is acquired.
  This function can also be called if this process already has the
  lock. In such case the function is executed immediately.

  This lock is primarily useful for compiler tasks that alter the build
  artifacts to avoid conflicts with a concurrent compilation.
  """
  @spec with_build_lock(keyword, (-> term())) :: term()
  def with_build_lock(config \\ config(), fun) do
    # To avoid duplicated compilation, we wrap compilation tasks, such
    # as compile.all, deps.compile, compile.elixir, compile.erlang in
    # a lock. Note that compile.all covers compile.elixir, but the
    # latter can still be invoked directly, so we put the lock over
    # each individual task.

    build_path = build_path(config)

    on_taken = fn os_pid ->
      Mix.shell().error([
        IO.ANSI.reset(),
        "Waiting for lock on the build directory (held by process #{os_pid})"
      ])
    end

    Mix.Sync.Lock.with_lock(build_path, fun, on_taken: on_taken)
  end

  @doc false
  def with_deps_lock(config \\ config(), fun) do
    # We wrap operations on the deps directory and on mix.lock to
    # avoid write conflicts.

    deps_path = deps_path(config)

    on_taken = fn os_pid ->
      Mix.shell().error([
        IO.ANSI.reset(),
        "Waiting for lock on the deps directory (held by process #{os_pid})"
      ])
    end

    Mix.Sync.Lock.with_lock(deps_path, fun, on_taken: on_taken)
  end

  # Loads mix.exs in the current directory or loads the project from the
  # mixfile cache and pushes the project onto the project stack.
  defp load_project(app, post_config) do
    Mix.ProjectStack.post_config(post_config)

    if cached = Mix.State.read_cache({:app, app}) do
      {project, file} = cached
      push(project, file, app)
      project
    else
      file = Path.expand("mix.exs")
      old_proj = get()

      {new_proj, file} =
        if File.regular?(file) do
          old_undefined = Code.get_compiler_option(:no_warn_undefined)

          try do
            Code.compiler_options(relative_paths: false, no_warn_undefined: :all)
            _ = Code.compile_file(file)
            get()
          else
            ^old_proj -> Mix.raise("Could not find a Mix project at #{file}")
            new_proj -> {new_proj, file}
          after
            Code.compiler_options(relative_paths: true, no_warn_undefined: old_undefined)
          end
        else
          push(nil, file, app)
          {nil, "nofile"}
        end

      Mix.State.write_cache({:app, app}, {new_proj, file})
      new_proj
    end
  end

  defp default_config do
    [
      aliases: [],
      build_per_environment: true,
      build_scm: Mix.SCM.Path,
      config_path: "config/config.exs",
      consolidate_protocols: true,
      deps: [],
      deps_path: "deps",
      elixirc_paths: ["lib"],
      erlc_paths: ["src"],
      erlc_include_path: "include",
      erlc_options: [],
      lockfile: "mix.lock",
      start_permanent: false
    ]
  end

  @private_config [:build_scm, :deps_app_path, :deps_build_path]
  defp get_project_config(nil), do: []
  defp get_project_config(atom), do: atom.project() |> Keyword.drop(@private_config)
end
