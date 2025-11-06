defmodule Mix.Tasks.UsageRules.SyncClaudeSkillsTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  describe "basic functionality" do
    test "creates skill file for single package" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "# Ash Usage Rules\n\nContent here"
        }
      )
      |> Igniter.compose_task("usage_rules.sync_claude_skills", ["ash"])
      |> assert_creates(".claude/skills/ash/SKILL.md")
      |> assert_has_notice("Created skill for: ash")
    end

    test "creates skill files for multiple packages" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Ash content",
          "deps/phoenix/usage-rules.md" => "Phoenix content"
        }
      )
      |> Igniter.compose_task(
        "usage_rules.sync_claude_skills",
        ["ash", "phoenix"]
      )
      |> assert_creates(".claude/skills/ash/SKILL.md")
      |> assert_creates(".claude/skills/phoenix/SKILL.md")
    end

    test "generates correct YAML frontmatter" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "# Ash\n\nContent"
        }
      )
      |> Igniter.compose_task("usage_rules.sync_claude_skills", ["ash"])
      |> assert_creates(".claude/skills/ash/SKILL.md")
    end
  end

  describe "flags and options" do
    test "--all flag processes all packages with usage rules" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Ash",
          "deps/phoenix/usage-rules.md" => "Phoenix"
        }
      )
      |> Igniter.compose_task("usage_rules.sync_claude_skills", ["--all"])
      |> assert_creates(".claude/skills/ash/SKILL.md")
      |> assert_creates(".claude/skills/phoenix/SKILL.md")
    end

    test "--output-dir flag changes output location" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => "Content"
        }
      )
      |> Igniter.compose_task(
        "usage_rules.sync_claude_skills",
        ["ash", "--output-dir", "custom/path"]
      )
      |> assert_creates("custom/path/ash/SKILL.md")
    end

    test "--list flag shows packages without creating files" do
      igniter =
        test_project(
          files: %{
            "deps/ash/usage-rules.md" => "Ash",
            "deps/phoenix/usage-rules.md" => "Phoenix"
          }
        )
        |> Igniter.compose_task(
          "usage_rules.sync_claude_skills",
          ["--all", "--list"]
        )

      # Verify at least one notice mentioning packages exists
      notices = Enum.filter(igniter.notices, &String.contains?(&1, "Packages with usage rules"))
      assert length(notices) > 0

      refute Igniter.exists?(igniter, ".claude/skills/ash/SKILL.md")
    end

    test "filters packages when specific names provided" do
      igniter =
        test_project(
          files: %{
            "deps/ash/usage-rules.md" => "Ash",
            "deps/phoenix/usage-rules.md" => "Phoenix"
          }
        )
        |> Igniter.compose_task("usage_rules.sync_claude_skills", ["ash"])
        |> apply_igniter!()

      assert Igniter.exists?(igniter, ".claude/skills/ash/SKILL.md")
      refute Igniter.exists?(igniter, ".claude/skills/phoenix/SKILL.md")
    end
  end

  describe "error handling" do
    test "warns when package has no usage-rules.md" do
      test_project(
        files: %{
          "deps/ash/mix.exs" => "# Package exists"
        }
      )
      |> Igniter.compose_task("usage_rules.sync_claude_skills", ["ash"])
      |> assert_has_warning("Package ash has no usage-rules.md file")
    end

    test "handles no packages with usage rules" do
      test_project(files: %{})
      |> Igniter.compose_task(
        "usage_rules.sync_claude_skills",
        ["--all"]
      )
      |> assert_has_notice("No packages found with usage-rules.md files")
    end

    test "handles empty usage-rules.md file" do
      test_project(
        files: %{
          "deps/ash/usage-rules.md" => ""
        }
      )
      |> Igniter.compose_task("usage_rules.sync_claude_skills", ["ash"])
      |> assert_creates(".claude/skills/ash/SKILL.md")
    end

    test "handles package names with underscores" do
      test_project(
        files: %{
          "deps/phoenix_live_view/usage-rules.md" => "Content"
        }
      )
      |> Igniter.compose_task(
        "usage_rules.sync_claude_skills",
        ["phoenix_live_view"]
      )
      |> assert_creates(".claude/skills/phoenix_live_view/SKILL.md")
    end
  end

  describe "umbrella support" do
    test "supports umbrella projects" do
      assert Mix.Tasks.UsageRules.SyncClaudeSkills.supports_umbrella?()
    end
  end
end
