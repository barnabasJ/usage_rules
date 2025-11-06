defmodule UsageRules.SkillGenerator do
  @moduledoc """
  Shared utilities for generating Claude skill files from package usage rules.

  This module provides functions for:
  - Discovering packages with usage-rules.md files
  - Formatting skill names
  - Generating YAML frontmatter
  - Assembling complete skill files
  """

  @doc """
  Finds all packages with usage-rules.md files.

  ## Parameters
  - igniter: Igniter context
  - filter: Optional list of package atoms to filter by

  ## Returns
  List of package atoms that have usage-rules.md files

  ## Examples
      iex> find_packages_with_usage_rules(igniter, [])
      [:ash, :phoenix, :ecto]

      iex> find_packages_with_usage_rules(igniter, [:ash])
      [:ash]
  """
  def find_packages_with_usage_rules(igniter, filter \\ []) do
    all_deps = get_all_deps(igniter)
    packages_with_rules = get_packages_with_usage_rules(igniter, all_deps)

    if Enum.empty?(filter) do
      Enum.map(packages_with_rules, fn {name, _path} -> name end)
    else
      packages_with_rules
      |> Enum.filter(fn {name, _path} -> name in filter end)
      |> Enum.map(fn {name, _path} -> name end)
    end
  end

  @doc """
  Gets the description for a package from Application.spec.

  Returns empty string if no description is available.

  ## Examples
      iex> get_package_description(:ash)
      "A declarative, resource-oriented framework"

      iex> get_package_description(:nonexistent)
      ""
  """
  def get_package_description(name) do
    case Application.spec(name, :description) do
      nil -> ""
      desc -> String.trim_trailing(to_string(desc))
    end
  end

  @doc """
  Formats a package name for use in skill YAML frontmatter.

  Converts snake_case package atoms to Title Case strings.

  ## Examples
      iex> format_skill_name(:ash)
      "Ash"

      iex> format_skill_name(:phoenix_live_view)
      "Phoenix Live View"
  """
  def format_skill_name(package) do
    package
    |> to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Generates YAML frontmatter for a skill file.

  ## Parameters
  - package: Package atom
  - description: Package description (ignored, kept for API compatibility)

  ## Returns
  YAML frontmatter string with name and description
  """
  def format_skill_frontmatter(package, _description) do
    name = format_skill_name(package)
    description_text = "Guidance on working with #{name}"

    """
    ---
    name: #{package}
    description: #{description_text}
    ---
    """
  end

  @doc """
  Generates complete skill file content with YAML frontmatter.

  ## Parameters
  - package: Package atom
  - description: Package description (empty string for default)
  - content: Usage rules content

  ## Returns
  Complete skill file content as string
  """
  def format_skill_file(package, description, content) do
    frontmatter = format_skill_frontmatter(package, description)
    frontmatter <> "\n" <> content
  end

  # Private helper functions extracted from usage_rules.sync.ex pattern

  defp get_all_deps(igniter) do
    # Get top-level deps
    top_level_deps =
      Mix.Project.get().project()[:deps] |> Enum.map(&elem(&1, 0))

    # Get umbrella deps if applicable
    umbrella_deps =
      (Mix.Project.apps_paths() || [])
      |> Enum.flat_map(fn {app, path} ->
        Mix.Project.in_project(app, path, fn _ ->
          Mix.Project.get().project()[:deps] |> Enum.map(&elem(&1, 0))
        end)
      end)

    all_dep_names = Enum.uniq(top_level_deps ++ umbrella_deps)

    # Get deps from Mix.Project.deps_paths
    mix_deps =
      Mix.Project.deps_paths()
      |> Enum.filter(fn {dep, _path} ->
        dep in all_dep_names
      end)
      |> Enum.map(fn {dep, path} ->
        {dep, Path.relative_to_cwd(path)}
      end)

    # Get deps from igniter (for test mode)
    igniter_deps = get_deps_from_igniter(igniter)
    (mix_deps ++ igniter_deps) |> Enum.uniq()
  end

  defp get_deps_from_igniter(igniter) do
    if igniter.assigns[:test_mode?] do
      igniter.rewrite.sources
      |> Enum.filter(fn {path, _source} ->
        String.match?(path, ~r|^deps/[^/]+/usage-rules\.md$|)
      end)
      |> Enum.map(fn {path, _source} ->
        # Extract package name from deps/package_name/usage-rules.md
        package_name =
          path
          |> String.split("/")
          |> Enum.at(1)
          |> String.to_atom()

        # Extract package path from deps/package_name/...
        package_path = Path.join("deps", to_string(package_name))

        {package_name, package_path}
      end)
      |> Enum.uniq()
    else
      []
    end
  end

  defp get_packages_with_usage_rules(igniter, all_deps) do
    Enum.filter(all_deps, fn
      {_name, path} when is_binary(path) and path != "" ->
        Igniter.exists?(igniter, Path.join(path, "usage-rules.md"))

      _ ->
        false
    end)
  end
end
