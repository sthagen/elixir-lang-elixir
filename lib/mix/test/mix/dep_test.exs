# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec

Code.require_file("../test_helper.exs", __DIR__)

defmodule Mix.DepTest do
  use MixTest.Case

  defmodule DepsApp do
    def project do
      [
        app: :deps_app,
        deps: [
          {:ok, "0.1.0", path: "deps/ok"},
          {:invalidvsn, "0.2.0", path: "deps/invalidvsn"},
          {:invalidapp, "0.1.0", path: "deps/invalidapp"},
          {:noappfile, "0.1.0", path: "deps/noappfile"},
          {:uncloned, git: "https://github.com/elixir-lang/uncloned.git"},
          {:optional, git: "https://github.com/elixir-lang/optional.git", optional: true}
        ]
      ]
    end
  end

  defmodule ProcessDepsApp do
    def project do
      [app: :process_deps_app, deps: Process.get(:mix_deps)]
    end
  end

  defp with_deps(deps, fun) do
    Process.put(:mix_deps, deps)
    Mix.Project.push(ProcessDepsApp)
    fun.()
  after
    Mix.Project.pop()
  end

  defp assert_wrong_dependency(deps) do
    with_deps(deps, fn ->
      assert_raise Mix.Error, ~r"Dependency specified in the wrong format", fn ->
        Mix.Dep.Converger.converge([])
      end
    end)
  end

  test "clear deps cache" do
    Mix.Project.push(DepsApp)

    Mix.Dep.cached()
    key = {:cached_deps, DepsApp}

    {env_target, deps} = Mix.State.read_cache(key)
    assert env_target == {Mix.env(), Mix.target()}
    assert length(deps) == 6

    Mix.Dep.clear_cached()
    refute Mix.State.read_cache(key)
  end

  test "extracts all dependencies from the given project" do
    in_fixture("deps_status", fn ->
      Mix.Project.push(DepsApp)

      deps = Mix.Dep.Converger.converge([])
      assert length(deps) == 6
      assert Enum.find(deps, &match?(%Mix.Dep{app: :ok, status: {:ok, _}}, &1))
      assert Enum.find(deps, &match?(%Mix.Dep{app: :invalidvsn, status: {:invalidvsn, :ok}}, &1))
      assert Enum.find(deps, &match?(%Mix.Dep{app: :invalidapp, status: {:invalidapp, _}}, &1))
      assert Enum.find(deps, &match?(%Mix.Dep{app: :noappfile, status: {:noappfile, {_, _}}}, &1))
      assert Enum.find(deps, &match?(%Mix.Dep{app: :uncloned, status: {:unavailable, _}}, &1))
      assert Enum.find(deps, &match?(%Mix.Dep{app: :optional, status: {:unavailable, _}}, &1))
    end)
  end

  test "extracts all dependencies paths/scms from the given project" do
    in_fixture("deps_status", fn ->
      Mix.Project.push(DepsApp)

      apps = Mix.Project.deps_apps()
      assert length(apps) == 6
      assert :ok in apps
      assert :uncloned in apps

      paths = Mix.Project.deps_paths()
      assert map_size(paths) == 6
      assert paths[:ok] =~ "deps/ok"
      assert paths[:uncloned] =~ "deps/uncloned"

      scms = Mix.Project.deps_scms()
      assert map_size(scms) == 6
      assert scms[:ok] == Mix.SCM.Path
      assert scms[:uncloned] == Mix.SCM.Git
    end)
  end

  test "fails on invalid dependencies" do
    assert_wrong_dependency([{:ok}])
    assert_wrong_dependency([{:ok, nil}])
    assert_wrong_dependency([{:ok, nil, []}])
  end

  test "use requirements for dependencies" do
    deps = [{:ok, "~> 0.1", path: "deps/ok"}]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        deps = Mix.Dep.Converger.converge([])
        assert Enum.find(deps, &match?(%Mix.Dep{app: :ok, status: {:ok, _}}, &1))
      end)
    end)
  end

  test "raises when no SCM is specified" do
    deps = [{:ok, "~> 0.1", not_really: :ok}]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        send(self(), {:mix_shell_input, :yes?, false})
        msg = "Could not find an SCM for dependency :ok from Mix.DepTest.ProcessDepsApp"
        assert_raise Mix.Error, msg, fn -> Mix.Dep.Converger.converge([]) end
      end)
    end)
  end

  test "does not set the manager before the dependency was loaded" do
    # It is important to not eagerly set the manager because the dependency
    # needs to be loaded (i.e. available in the file system) in order to get
    # the proper manager.
    Mix.Project.push(DepsApp)

    {_, true, _} =
      Mix.Dep.Converger.converge(false, [], nil, fn dep, acc, lock ->
        assert is_nil(dep.manager)
        {dep, acc or true, lock}
      end)
  end

  test "raises on invalid deps req" do
    deps = [{:ok, "+- 0.1.0", path: "deps/ok"}]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        assert_raise Mix.Error, ~r"Invalid requirement", fn ->
          Mix.Dep.Converger.converge([])
        end
      end)
    end)
  end

  test "nested deps come first" do
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"}]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        assert Enum.map(Mix.Dep.Converger.converge([]), & &1.app) == [:git_repo, :deps_repo]
      end)
    end)
  end

  test "nested optional deps are never added" do
    deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"}]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        File.write!("custom/deps_repo/mix.exs", """
        defmodule DepsRepo do
          use Mix.Project

          def project do
            [app: :deps_repo,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), optional: true}]]
          end
        end
        """)

        assert Enum.map(Mix.Dep.Converger.converge([]), & &1.app) == [:deps_repo]
      end)
    end)
  end

  test "nested deps with convergence" do
    deps = [
      {:deps_repo, "0.1.0", path: "custom/deps_repo"},
      {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        assert Enum.map(Mix.Dep.Converger.converge([]), & &1.app) == [:git_repo, :deps_repo]
      end)
    end)
  end

  test "nested deps with convergence and managers" do
    Process.put(:custom_deps_git_repo_opts, manager: :make)

    deps = [
      {:deps_repo, "0.1.0", path: "custom/deps_repo", manager: :rebar3},
      {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        [dep1, dep2] = Mix.Dep.Converger.converge([])
        assert dep1.manager == nil
        assert dep2.manager == :rebar3
      end)
    end)
  end

  test "nested deps with optional matching" do
    Process.put(:custom_deps_git_repo_opts, optional: true)

    # deps_repo brings git_repo but it is optional
    deps = [
      {:deps_repo, "0.1.0", path: "custom/deps_repo"},
      {:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo")}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        File.mkdir_p!("custom/deps_repo/lib")

        File.write!("custom/deps_repo/lib/a.ex", """
        # Check that the child dependency is top_level and optional
        [%Mix.Dep{app: :git_repo, top_level: true, opts: opts}] = Mix.Dep.cached()
        true = Keyword.fetch!(opts, :optional)
        """)

        Mix.Tasks.Deps.Get.run([])
        Mix.Tasks.Deps.Compile.run([])
      end)
    end)
  end

  test "nested deps with convergence and optional dependencies" do
    deps = [
      {:deps_repo, "0.1.0", path: "custom/deps_repo"},
      {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        File.write!("custom/deps_repo/mix.exs", """
        defmodule DepsRepo do
          use Mix.Project

          def project do
            [app: :deps_repo,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), optional: true}]]
          end
        end
        """)

        assert Enum.map(Mix.Dep.Converger.converge([]), & &1.app) == [:git_repo, :deps_repo]
      end)
    end)
  end

  test "nested deps with optional dependencies and cousin conflict" do
    deps = [
      {:deps_repo1, "0.1.0", path: "custom/deps_repo1"},
      {:deps_repo2, "0.1.0", path: "custom/deps_repo2"}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        File.mkdir_p!("custom/deps_repo1")

        File.write!("custom/deps_repo1/mix.exs", """
        defmodule DepsRepo1 do
          use Mix.Project

          def project do
            [app: :deps_repo1,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), optional: true}]]
          end
        end
        """)

        File.mkdir_p!("custom/deps_repo2")

        File.write!("custom/deps_repo2/mix.exs", """
        defmodule DepsRepo2 do
          use Mix.Project

          def project do
            [app: :deps_repo2,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", path: "somewhere"}]]
          end
        end
        """)

        Mix.Tasks.Deps.run([])
        assert_received {:mix_shell, :info, ["* deps_repo1" <> _]}
        assert_received {:mix_shell, :info, ["* deps_repo2" <> _]}
        assert_received {:mix_shell, :info, ["* git_repo" <> _]}

        assert_received {:mix_shell, :info,
                         ["  different specs were given for the git_repo app" <> _]}
      end)
    end)
  end

  test "nested deps with optional dependencies and cousin conflict (reverse order)" do
    deps = [
      {:deps_repo2, "0.1.0", path: "custom/deps_repo2"},
      {:deps_repo1, "0.1.0", path: "custom/deps_repo1"}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        File.mkdir_p!("custom/deps_repo1")

        File.write!("custom/deps_repo1/mix.exs", """
        defmodule DepsRepo1 do
          use Mix.Project

          def project do
            [app: :deps_repo1,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), optional: true}]]
          end
        end
        """)

        File.mkdir_p!("custom/deps_repo2")

        File.write!("custom/deps_repo2/mix.exs", """
        defmodule DepsRepo2 do
          use Mix.Project

          def project do
            [app: :deps_repo2,
             version: "0.1.0",
             deps: [{:git_repo, "0.2.0", path: "somewhere"}]]
          end
        end
        """)

        Mix.Tasks.Deps.run([])
        assert_received {:mix_shell, :info, ["* deps_repo1" <> _]}
        assert_received {:mix_shell, :info, ["* deps_repo2" <> _]}
        assert_received {:mix_shell, :info, ["* git_repo" <> _]}

        assert_received {:mix_shell, :info,
                         ["  different specs were given for the git_repo app" <> _]}
      end)
    end)
  end

  test "deps with system_env set" do
    file_path = tmp_path("load dependency with env vars/dep-test")
    dep_path = tmp_path("rebar_dep")

    system_env = [{"FILE_FROM_ENV", file_path}, {"CONTENTS_FROM_ENV", "contents dep test"}]
    deps = [{:rebar_dep, path: dep_path, app: false, manager: :rebar3, system_env: system_env}]

    with_deps(deps, fn ->
      in_tmp("load dependency with env vars", fn ->
        Mix.Dep.Converger.converge([])
        assert {:ok, "contents dep test"} = File.read(file_path)
      end)
    end)
  end

  test "diverged with system_env set" do
    Process.put(:custom_deps_git_repo_opts, system_env: [{"FOO", "BAR"}])

    deps = [
      {:deps_repo, "0.1.0", path: "custom/deps_repo"},
      {:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo")}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        [git_repo, _] = Mix.Dep.Converger.converge([])
        %{app: :git_repo, status: {:overridden, _}} = git_repo
      end)
    end)
  end

  ## Remote converger

  defmodule IdentityRemoteConverger do
    @behaviour Mix.RemoteConverger

    def remote?(%Mix.Dep{app: :deps_repo}), do: false
    def remote?(%Mix.Dep{}), do: true
    def deps(_dep, _lock), do: []
    def post_converge, do: :ok

    def converge(deps, lock) do
      Process.put(:remote_converger, deps)
      lock
    end
  end

  test "remote converger" do
    deps = [
      {:deps_repo, "0.1.0", path: "custom/deps_repo"},
      {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo")}
    ]

    with_deps(deps, fn ->
      Mix.RemoteConverger.register(IdentityRemoteConverger)

      in_fixture("deps_status", fn ->
        Mix.Tasks.Deps.Get.run([])

        message = "* Getting git_repo (#{fixture_path("git_repo")})"
        assert_received {:mix_shell, :info, [^message]}

        assert Process.get(:remote_converger)
      end)
    end)
  after
    Mix.RemoteConverger.register(nil)
  end

  defmodule DivergingRemoteConverger do
    @behaviour Mix.RemoteConverger

    def remote?(%Mix.Dep{app: :deps_repo, scm: Mix.SCM.Path}), do: true
    def remote?(%Mix.Dep{app: :git_repo, scm: Mix.SCM.Path}), do: true
    def remote?(%Mix.Dep{}), do: false
    def deps(%Mix.Dep{app: :deps_repo}, _lock), do: [{:git_repo, path: "custom/git_repo"}]
    def deps(%Mix.Dep{app: :git_repo}, _lock), do: []
    def post_converge, do: :ok

    def converge(_deps, lock) do
      lock
      |> Map.put(:deps_repo, :custom)
      |> Map.put(:git_repo, :custom)
    end
  end

  test "converger detects diverged deps from remote converger" do
    deps = [
      {:deps_on_git_repo, "0.2.0", git: MixTest.Case.fixture_path("deps_on_git_repo")},
      {:deps_repo, "0.1.0", path: "custom/deps_repo"}
    ]

    with_deps(deps, fn ->
      Mix.RemoteConverger.register(DivergingRemoteConverger)

      in_fixture("deps_status", fn ->
        assert_raise Mix.Error, fn ->
          Mix.Tasks.Deps.Get.run([])
        end

        assert_received {:mix_shell, :error, ["Dependencies have diverged:"]}
      end)
    end)
  after
    Mix.RemoteConverger.register(nil)
  end

  test "pass dependencies to remote converger in defined order" do
    deps = [
      {:ok, "0.1.0", path: "deps/ok"},
      {:invalidvsn, "0.2.0", path: "deps/invalidvsn"},
      {:deps_repo, "0.1.0", path: "custom/deps_repo"},
      {:invalidapp, "0.1.0", path: "deps/invalidapp"},
      {:noappfile, "0.1.0", path: "deps/noappfile"}
    ]

    with_deps(deps, fn ->
      Mix.RemoteConverger.register(IdentityRemoteConverger)

      in_fixture("deps_status", fn ->
        Mix.Tasks.Deps.Get.run([])

        deps = Process.get(:remote_converger) |> Enum.map(& &1.app)
        assert deps == [:ok, :invalidvsn, :deps_repo, :invalidapp, :noappfile, :git_repo]
      end)
    end)
  after
    Mix.RemoteConverger.register(nil)
  end

  defmodule RaiseRemoteConverger do
    @behaviour Mix.RemoteConverger

    def remote?(_app), do: false
    def deps(_dep, _lock), do: :ok
    def post_converge, do: :ok

    def converge(_deps, lock) do
      Process.put(:remote_converger, true)
      lock
    end
  end

  test "remote converger is not invoked if deps diverge" do
    deps = [
      {:deps_repo, "0.1.0", path: "custom/deps_repo"},
      {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}
    ]

    with_deps(deps, fn ->
      Mix.RemoteConverger.register(RaiseRemoteConverger)

      in_fixture("deps_status", fn ->
        assert_raise Mix.Error, fn ->
          Mix.Tasks.Deps.Get.run([])
        end

        assert_received {:mix_shell, :error, ["Dependencies have diverged:"]}
        refute Process.get(:remote_converger)
      end)
    end)
  after
    Mix.RemoteConverger.register(nil)
  end

  test "remote converger is not invoked if deps graph has cycles" do
    deps = [{:app1, "0.1.0", path: "app1"}, {:app2, "0.1.0", path: "app2"}]

    with_deps(deps, fn ->
      Mix.RemoteConverger.register(RaiseRemoteConverger)

      in_fixture("deps_cycle", fn ->
        assert_raise Mix.Error, ~r/Could not sort dependencies/, fn ->
          Mix.Tasks.Deps.Get.run([])
        end

        refute Process.get(:remote_converger)
      end)
    end)
  after
    Mix.RemoteConverger.register(nil)
  end

  defp sorted_keys(map) do
    map |> Map.keys() |> Enum.sort()
  end

  test "deps_paths" do
    deps = [
      {:abc_repo, "0.1.0", path: "custom/abc_repo"},
      {:deps_repo, "0.1.0", path: "custom/deps_repo"}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        # Both orders below are valid after topological sort
        assert Enum.map(Mix.Dep.Converger.converge([]), & &1.app) in [
                 [:git_repo, :abc_repo, :deps_repo],
                 [:abc_repo, :git_repo, :deps_repo]
               ]

        assert sorted_keys(Mix.Project.deps_paths()) == [:abc_repo, :deps_repo, :git_repo]

        assert sorted_keys(Mix.Project.deps_paths(depth: 1)) == [:abc_repo, :deps_repo]
        assert sorted_keys(Mix.Project.deps_paths(depth: 2)) == [:abc_repo, :deps_repo, :git_repo]
        assert sorted_keys(Mix.Project.deps_paths(depth: 3)) == [:abc_repo, :deps_repo, :git_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:abc_repo])) == [:abc_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:deps_repo])) == [
                 :deps_repo,
                 :git_repo
               ]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:git_repo])) == [:git_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:abc_repo], depth: 1)) == [:abc_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:deps_repo], depth: 1)) == [
                 :deps_repo
               ]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:git_repo], depth: 1)) == [:git_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:abc_repo], depth: 2)) == [:abc_repo]
        assert sorted_keys(Mix.Project.deps_paths(parents: [:git_repo], depth: 2)) == [:git_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:deps_repo], depth: 2)) ==
                 [:deps_repo, :git_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:abc_repo, :deps_repo])) ==
                 [:abc_repo, :deps_repo, :git_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:abc_repo, :deps_repo], depth: 1)) ==
                 [:abc_repo, :deps_repo]

        assert sorted_keys(Mix.Project.deps_paths(parents: [:abc_repo, :deps_repo], depth: 2)) ==
                 [:abc_repo, :deps_repo, :git_repo]
      end)
    end)
  end

  test "deps_tree" do
    deps = [
      {:abc_repo, "0.1.0", path: "custom/abc_repo"},
      {:deps_repo, "0.1.0", path: "custom/deps_repo"}
    ]

    with_deps(deps, fn ->
      in_fixture("deps_status", fn ->
        # Both orders below are valid after topological sort
        assert Enum.map(Mix.Dep.Converger.converge([]), & &1.app) in [
                 [:git_repo, :abc_repo, :deps_repo],
                 [:abc_repo, :git_repo, :deps_repo]
               ]

        assert %{abc_repo: [], deps_repo: [:git_repo]} = Mix.Project.deps_tree(depth: 1)

        assert %{abc_repo: [], deps_repo: [:git_repo], git_repo: []} =
                 Mix.Project.deps_tree(depth: 2)

        assert %{abc_repo: [], deps_repo: [:git_repo], git_repo: []} =
                 Mix.Project.deps_tree(depth: 3)

        assert %{abc_repo: []} = Mix.Project.deps_tree(parents: [:abc_repo])

        assert %{deps_repo: [:git_repo], git_repo: []} =
                 Mix.Project.deps_tree(parents: [:deps_repo])

        assert %{git_repo: []} = Mix.Project.deps_tree(parents: [:git_repo])

        assert %{abc_repo: []} = Mix.Project.deps_tree(parents: [:abc_repo], depth: 1)
        assert %{deps_repo: [:git_repo]} = Mix.Project.deps_tree(parents: [:deps_repo], depth: 1)
      end)
    end)
  end

  describe "only handling" do
    test "extracts deps matching environment" do
      deps = [
        {:foo, github: "elixir-lang/foo"},
        {:bar, github: "elixir-lang/bar", only: :other_env}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          deps = Mix.Dep.Converger.converge(env: :other_env)
          assert length(deps) == 2

          deps = Mix.Dep.Converger.converge([])
          assert length(deps) == 2

          assert [dep] = Mix.Dep.Converger.converge(env: :prod)
          assert dep.app == :foo
        end)
      end)
    end

    test "fetches parent deps matching specified env" do
      deps = [{:only, github: "elixir-lang/only", only: [:dev]}]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          Mix.Tasks.Deps.Get.run(["--only", "prod"])
          refute_received {:mix_shell, :info, ["* Getting" <> _]}

          assert_raise Mix.Error, "Can't continue due to errors on dependencies", fn ->
            Mix.Tasks.Deps.Loadpaths.run([])
          end

          Mix.State.clear_cache()
          Mix.env(:prod)
          Mix.Tasks.Deps.Loadpaths.run([])
        end)
      end)
    end

    test "selects only prod dependencies on nested deps" do
      Process.put(:custom_deps_git_repo_opts, only: :test)
      deps = [{:deps_repo, "0.1.0", path: "custom/deps_repo"}]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:deps_repo] = Enum.map(loaded, & &1.app)

          loaded = Mix.Dep.Converger.converge(env: :test)
          assert [:deps_repo] = Enum.map(loaded, & &1.app)
        end)
      end)
    end

    test "conflicts on nested deps" do
      # deps_repo wants all git_repo, git_repo is restricted to only test
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedonly: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :dev)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedonly: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :test)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedonly: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          Mix.Tasks.Deps.run([])
          assert_received {:mix_shell, :info, ["* deps_repo" <> _]}
          assert_received {:mix_shell, :info, [_]}
          assert_received {:mix_shell, :info, ["* git_repo" <> _]}
          assert_received {:mix_shell, :info, [msg]}
          assert msg =~ "Remove the :only restriction from your dep"
        end)
      end)
    end

    test "does not conflict with optional deps on nested deps" do
      Process.put(:custom_deps_git_repo_opts, optional: true)

      # deps_repo wants all git_repo, git_repo is restricted to only test
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :dev)
          assert [:deps_repo] = Enum.map(loaded, & &1.app)
          assert [noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :test)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)
        end)
      end)
    end

    test "does not conflict with optional deps on nested deps (reverse order)" do
      Process.put(:custom_deps_git_repo_opts, optional: true)

      # deps_repo wants all git_repo, git_repo is restricted to only test
      deps = [
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: :test},
        {:deps_repo, "0.1.0", path: "custom/deps_repo"}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :dev)
          assert [:deps_repo] = Enum.map(loaded, & &1.app)
          assert [noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :test)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)
        end)
      end)
    end

    test "does not conflict on valid subsets on nested deps" do
      # deps_repo wants git_repo for prod, git_repo is restricted to only prod and test
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: [:prod, :test]}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :dev)
          assert [] = Enum.map(loaded, & &1.app)

          loaded = Mix.Dep.Converger.converge(env: :test)
          assert [:git_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :prod)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)
        end)
      end)
    end

    test "conflicts on invalid only subset on nested deps" do
      # deps_repo wants git_repo for dev, git_repo is restricted to only test
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", only: :dev},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), only: [:test]}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedonly: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :dev)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedonly: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :test)
          assert [:git_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _] = Enum.map(loaded, & &1.status)

          Mix.Tasks.Deps.run([])
          assert_received {:mix_shell, :info, ["* deps_repo" <> _]}
          assert_received {:mix_shell, :info, [_]}
          assert_received {:mix_shell, :info, ["* git_repo" <> _]}
          assert_received {:mix_shell, :info, [msg]}
          assert msg =~ "Ensure you specify at least the same environments in :only in your dep"
        end)
      end)
    end

    test "does not conflict with valid only in both parent and child on nested deps" do
      Process.put(:custom_deps_git_repo_opts, only: :test)

      # deps_repo has environment set to test so it loads the deps_git_repo set to test too
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", env: :test, only: [:dev, :test]},
        {:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo"), only: :test}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :dev)
          assert [:deps_repo] = Enum.map(loaded, & &1.app)
          assert [noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :test)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(env: :prod)
          assert [] = Enum.map(loaded, & &1.app)
        end)
      end)
    end

    test "converges and diverges when only is not in_upper" do
      loaded = fn deps ->
        with_deps(deps, fn ->
          in_fixture("deps_status", fn ->
            File.mkdir_p!("custom/other_repo")

            File.write!("custom/other_repo/mix.exs", """
            defmodule OtherRepo do
              use Mix.Project

              def project do
                [app: :other_repo,
                 version: "0.1.0",
                 deps: [{:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo")}]]
              end
            end
            """)

            Mix.State.clear_cache()
            loaded = Mix.Dep.Converger.converge([])
            Enum.map(loaded, &{&1.app, &1.opts[:only]})
          end)
        end)
      end

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
        {:other_repo, "0.1.0", path: "custom/other_repo", only: :test}
      ]

      assert loaded.(deps) == [git_repo: [:test, :prod], other_repo: :test, deps_repo: :prod]

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:other_repo, "0.1.0", path: "custom/other_repo", only: :test}
      ]

      assert loaded.(deps) == [git_repo: nil, other_repo: :test, deps_repo: nil]

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
        {:other_repo, "0.1.0", path: "custom/other_repo"}
      ]

      assert loaded.(deps) == [git_repo: nil, other_repo: nil, deps_repo: :prod]

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:other_repo, "0.1.0", path: "custom/other_repo"}
      ]

      assert loaded.(deps) == [git_repo: nil, other_repo: nil, deps_repo: nil]

      Process.put(:custom_deps_git_repo_opts, optional: true)

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", only: :prod},
        {:other_repo, "0.1.0", path: "custom/other_repo", only: :test}
      ]

      assert loaded.(deps) == [git_repo: :test, other_repo: :test, deps_repo: :prod]
    end

    test "converges and diverges when only is not specified" do
      Process.put(:custom_deps_git_repo_opts, only: :test)

      deps = [
        {:abc_repo, "0.1.0", path: "custom/abc_repo", from_umbrella: true},
        {:deps_repo, "0.1.0", path: "custom/deps_repo", from_umbrella: true}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          File.mkdir_p!("custom/abc_repo")

          File.write!("custom/abc_repo/mix.exs", """
          defmodule OtherRepo do
            use Mix.Project

            def project do
              [app: :abc_repo,
               version: "0.1.0",
               deps: [{:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo")}]]
            end
          end
          """)

          Mix.Tasks.Deps.Get.run([])
          Mix.Tasks.Deps.Compile.run([])
          refute_receive {:mix_shell, :error, ["Could not compile :git_repo" <> _]}, 100
        end)
      end)
    end
  end

  describe "targets handling" do
    test "extracts deps matching target" do
      deps = [
        {:foo, github: "elixir-lang/foo"},
        {:bar, github: "elixir-lang/bar", targets: :rpi3}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          deps = Mix.Dep.Converger.converge(target: :rpi3)
          assert length(deps) == 2

          deps = Mix.Dep.Converger.converge([])
          assert length(deps) == 2

          assert [dep] = Mix.Dep.Converger.converge(target: :host)
          assert dep.app == :foo
        end)
      end)
    end

    test "fetches parent deps matching specified target" do
      deps = [{:target, github: "elixir-lang/target", targets: [:host]}]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          Mix.Tasks.Deps.Get.run(["--target", "rpi3"])
          refute_received {:mix_shell, :info, ["* Getting" <> _]}

          assert_raise Mix.Error, "Can't continue due to errors on dependencies", fn ->
            Mix.Tasks.Deps.Loadpaths.run([])
          end

          Mix.State.clear_cache()
          Mix.target(:rpi3)
          Mix.Tasks.Deps.Loadpaths.run([])
        end)
      end)
    end

    test "conflicts on nested deps" do
      # deps_repo wants all git_repo, git_repo is restricted to targets rpi3
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), targets: :rpi3}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedtargets: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :host)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedtargets: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :rpi3)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedtargets: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          Mix.Tasks.Deps.run([])
          assert_received {:mix_shell, :info, ["* deps_repo" <> _]}
          assert_received {:mix_shell, :info, [_]}
          assert_received {:mix_shell, :info, ["* git_repo" <> _]}
          assert_received {:mix_shell, :info, [msg]}
          assert msg =~ "Remove the :targets restriction from your dep"
        end)
      end)
    end

    test "does not conflict with optional deps on nested deps" do
      Process.put(:custom_deps_git_repo_opts, optional: true)

      # deps_repo wants all git_repo, git_repo is restricted to targets rpi3
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), targets: :rpi3}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :host)
          assert [:deps_repo] = Enum.map(loaded, & &1.app)
          assert [noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :rpi3)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)
        end)
      end)
    end

    test "does not conflict on valid subsets on nested deps" do
      # deps_repo wants git_repo for prod, git_repo is restricted to targets bbb and rpi3
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", targets: :rpi3},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), targets: [:bbb, :rpi3]}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :host)
          assert [] = Enum.map(loaded, & &1.app)

          loaded = Mix.Dep.Converger.converge(target: :bbb)
          assert [:git_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :rpi3)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)
        end)
      end)
    end

    test "conflicts on invalid only subset on nested deps" do
      # deps_repo wants git_repo for rpi3, git_repo is restricted to only test
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", targets: :host},
        {:git_repo, "0.2.0", git: MixTest.Case.fixture_path("git_repo"), targets: [:rpi3]}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedtargets: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :host)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [divergedtargets: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :rpi3)
          assert [:git_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _] = Enum.map(loaded, & &1.status)

          Mix.Tasks.Deps.run([])
          assert_received {:mix_shell, :info, ["* deps_repo" <> _]}
          assert_received {:mix_shell, :info, [_]}
          assert_received {:mix_shell, :info, ["* git_repo" <> _]}
          assert_received {:mix_shell, :info, [msg]}
          assert msg =~ "Ensure you specify at least the same targets in :targets in your dep"
        end)
      end)
    end

    test "does not conflict with valid only in both parent and child on nested deps" do
      Process.put(:custom_deps_git_repo_opts, targets: :bbb)

      # deps_repo has environment set to bbb so it loads the deps_git_repo set to bbb too
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", env: :test, targets: [:host, :bbb]},
        {:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo"), targets: :bbb}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          loaded = Mix.Dep.Converger.converge([])
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :host)
          assert [:deps_repo] = Enum.map(loaded, & &1.app)
          assert [noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :bbb)
          assert [:git_repo, :deps_repo] = Enum.map(loaded, & &1.app)
          assert [unavailable: _, noappfile: {_, _}] = Enum.map(loaded, & &1.status)

          loaded = Mix.Dep.Converger.converge(target: :rpi3)
          assert [] = Enum.map(loaded, & &1.app)
        end)
      end)
    end

    test "converges and diverges when only is not in_upper" do
      loaded = fn deps ->
        with_deps(deps, fn ->
          in_fixture("deps_status", fn ->
            File.mkdir_p!("custom/other_repo")

            File.write!("custom/other_repo/mix.exs", """
            defmodule OtherRepo do
              use Mix.Project

              def project do
                [app: :other_repo,
                 version: "0.1.0",
                 deps: [{:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo")}]]
              end
            end
            """)

            Mix.State.clear_cache()
            loaded = Mix.Dep.Converger.converge([])
            Enum.map(loaded, &{&1.app, &1.opts[:targets]})
          end)
        end)
      end

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", targets: :rpi3},
        {:other_repo, "0.1.0", path: "custom/other_repo", targets: :bbb}
      ]

      assert loaded.(deps) == [git_repo: [:bbb, :rpi3], other_repo: :bbb, deps_repo: :rpi3]

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:other_repo, "0.1.0", path: "custom/other_repo", targets: :bbb}
      ]

      assert loaded.(deps) == [git_repo: nil, other_repo: :bbb, deps_repo: nil]

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", targets: :rpi3},
        {:other_repo, "0.1.0", path: "custom/other_repo"}
      ]

      assert loaded.(deps) == [git_repo: nil, other_repo: nil, deps_repo: :rpi3]

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:other_repo, "0.1.0", path: "custom/other_repo"}
      ]

      assert loaded.(deps) == [git_repo: nil, other_repo: nil, deps_repo: nil]

      Process.put(:custom_deps_git_repo_opts, optional: true)

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", targets: :rpi3},
        {:other_repo, "0.1.0", path: "custom/other_repo", targets: :bbb}
      ]

      assert loaded.(deps) == [git_repo: :bbb, other_repo: :bbb, deps_repo: :rpi3]
    end
  end

  describe "overrides" do
    test "are not required when there are no conflicts" do
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          File.mkdir_p!("custom/deps_repo/lib")

          File.write!("custom/deps_repo/lib/a.ex", """
          # Check that the child dependency is top_level
          [%Mix.Dep{app: :git_repo, top_level: true}] = Mix.Dep.cached()
          """)

          Mix.Tasks.Deps.Get.run([])
          Mix.Tasks.Deps.Compile.run([])
        end)
      end)
    end

    test "are required when there are conflicts" do
      # deps_repo brings git_repo but it is overridden
      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:git_repo, ">= 0.0.0", git: MixTest.Case.fixture_path("git_repo"), override: true}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          File.mkdir_p!("custom/deps_repo/lib")

          File.write!("custom/deps_repo/lib/a.ex", """
          # Check that the overridden requirement shows up in the child dependency
          [%Mix.Dep{app: :git_repo, requirement: ">= 0.0.0"}] = Mix.Dep.cached()
          """)

          Mix.Tasks.Deps.Get.run([])
          Mix.Tasks.Deps.Compile.run([])
        end)
      end)
    end
  end

  describe "app generation" do
    test "considers runtime from current app on nested deps" do
      Process.put(:custom_deps_git_repo_opts, runtime: false)

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo"},
        {:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo")}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          Mix.Tasks.Deps.Compile.run([])

          {:ok, [{:application, :deps_repo, opts}]} =
            :file.consult("_build/dev/lib/deps_repo/ebin/deps_repo.app")

          assert :git_repo not in Keyword.get(opts, :applications)
        end)
      end)
    end

    test "considers only from current app on nested deps" do
      Process.put(:custom_deps_git_repo_opts, only: :other)

      deps = [
        {:deps_repo, "0.1.0", path: "custom/deps_repo", from_umbrella: true},
        {:git_repo, "0.1.0", git: MixTest.Case.fixture_path("git_repo"), from_umbrella: true}
      ]

      with_deps(deps, fn ->
        in_fixture("deps_status", fn ->
          Mix.Tasks.Deps.Compile.run([])

          {:ok, [{:application, :deps_repo, opts}]} =
            :file.consult("_build/dev/lib/deps_repo/ebin/deps_repo.app")

          assert :git_repo not in Keyword.get(opts, :applications)
        end)
      end)
    end
  end
end
