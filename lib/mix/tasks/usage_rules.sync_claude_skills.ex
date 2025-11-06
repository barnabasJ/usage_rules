defmodule Mix.Tasks.UsageRules.SyncClaudeSkills.Docs do
  @moduledoc false

  def short_doc do
    "Generates Claude skills from package usage rules"
  end

  def example do
    "mix usage_rules.sync_claude_skills ash phoenix"
  end

  def long_doc do
    """
    ## Usage

    Generate skills for all packages:
      mix usage_rules.sync_claude_skills --all

    Generate skills for specific packages:
      mix usage_rules.sync_claude_skills ash phoenix ecto

    ## Options

    * `--output-dir` - Custom output directory (default: .claude/skills/)
    * `--all` - Process all packages with usage rules
    * `--list` - List packages without generating files

    ## Output

    Creates `.claude/skills/<package>/SKILL.md` files with:
    - YAML frontmatter (name, description, aliases)
    - Complete usage-rules.md content

    Skills are generated in your project directory and can be used
    immediately by Claude Code.
    """
  end
end

defmodule Mix.Tasks.UsageRules.SyncClaudeSkills do
  @shortdoc Mix.Tasks.UsageRules.SyncClaudeSkills.Docs.short_doc()
  @moduledoc Mix.Tasks.UsageRules.SyncClaudeSkills.Docs.long_doc()

  use Igniter.Mix.Task

  alias UsageRules.SkillGenerator

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{
      group: :usage_rules,
      example: Mix.Tasks.UsageRules.SyncClaudeSkills.Docs.example(),
      positional: [packages: [optional: true, rest: true]],
      schema: [
        output_dir: :string,
        all: :boolean,
        list: :boolean
      ],
      defaults: [
        all: false
      ]
    }
  end

  @impl Igniter.Mix.Task
  def supports_umbrella?, do: true

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    # Add all usage-rules.md files from deps directory to igniter
    igniter =
      igniter
      |> Igniter.include_glob("deps/*/usage-rules.md")

    # Resolve output directory
    output_dir =
      case igniter.args.options[:output_dir] do
        nil -> ".claude/skills"
        dir -> dir
      end

    # Discover packages with usage rules
    packages_to_process =
      cond do
        # Explicit list of packages provided
        is_list(igniter.args.positional[:packages]) and
            igniter.args.positional[:packages] != [] ->
          Enum.map(igniter.args.positional[:packages], &String.to_atom/1)

        # --all flag provided
        igniter.args.options[:all] ->
          SkillGenerator.find_packages_with_usage_rules(igniter, [])

        # No packages and no --all flag
        true ->
          []
      end

    # Handle --list flag
    if igniter.args.options[:list] do
      if Enum.empty?(packages_to_process) do
        Igniter.add_notice(igniter, "No packages found with usage-rules.md files")
      else
        message =
          "Packages with usage rules:\n" <>
            Enum.map_join(packages_to_process, "\n", &"  - #{&1}")

        Igniter.add_notice(igniter, message)
      end
    else
      # Process each package and generate skill files
      if Enum.empty?(packages_to_process) do
        Igniter.add_notice(igniter, "No packages found with usage-rules.md files")
      else
        Enum.reduce(packages_to_process, igniter, fn package, acc_igniter ->
          process_package(acc_igniter, package, output_dir)
        end)
      end
    end
  end

  defp process_package(igniter, package, output_dir) do
    # Determine the package path from deps
    package_str = to_string(package)
    usage_rules_path = Path.join(["deps", package_str, "usage-rules.md"])

    case Igniter.exists?(igniter, usage_rules_path) do
      false ->
        Igniter.add_warning(
          igniter,
          "Package #{package} has no usage-rules.md file"
        )

      true ->
        generate_skill_file(igniter, package, usage_rules_path, output_dir)
    end
  end

  defp generate_skill_file(igniter, package, usage_rules_path, output_dir) do
    # Read usage rules content
    case Rewrite.source(igniter.rewrite, usage_rules_path) do
      {:ok, source} ->
        content = Rewrite.Source.get(source, :content)

        # Get package description
        description = SkillGenerator.get_package_description(package)

        # Format complete skill file
        skill_content =
          SkillGenerator.format_skill_file(
            package,
            description,
            content
          )

        # Create skill file path
        skill_path = Path.join([output_dir, to_string(package), "SKILL.md"])

        # Write skill file
        igniter
        |> Igniter.create_or_update_file(skill_path, skill_content, fn source ->
          Rewrite.Source.update(source, :content, skill_content)
        end)
        |> Igniter.add_notice("Created skill for: #{package}")

      {:error, _} ->
        # Fallback to reading from filesystem
        case File.read(usage_rules_path) do
          {:ok, content} ->
            # Get package description
            description = SkillGenerator.get_package_description(package)

            # Format complete skill file
            skill_content =
              SkillGenerator.format_skill_file(
                package,
                description,
                content
              )

            # Create skill file path
            skill_path = Path.join([output_dir, to_string(package), "SKILL.md"])

            # Write skill file
            igniter
            |> Igniter.create_or_update_file(skill_path, skill_content, fn source ->
              Rewrite.Source.update(source, :content, skill_content)
            end)
            |> Igniter.add_notice("Created skill for: #{package}")

          {:error, reason} ->
            Igniter.add_warning(
              igniter,
              "Failed to read #{usage_rules_path}: #{reason}"
            )
        end
    end
  end
end
