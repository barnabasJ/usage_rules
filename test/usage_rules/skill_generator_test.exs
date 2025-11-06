defmodule UsageRules.SkillGeneratorTest do
  use ExUnit.Case, async: true

  alias UsageRules.SkillGenerator

  describe "format_skill_name/1" do
    test "formats single word package names" do
      assert SkillGenerator.format_skill_name(:ash) == "Ash"
    end

    test "formats multi-word package names" do
      assert SkillGenerator.format_skill_name(:phoenix_live_view) == "Phoenix Live View"
    end

    test "handles package names with numbers" do
      assert SkillGenerator.format_skill_name(:ex_doc) == "Ex Doc"
    end
  end

  describe "format_skill_frontmatter/2" do
    test "generates frontmatter with standard description format" do
      frontmatter = SkillGenerator.format_skill_frontmatter(:ash, "")

      assert frontmatter =~ "---"
      assert frontmatter =~ "name: ash"
      assert frontmatter =~ "description: Guidance on working with Ash"
      refute frontmatter =~ "aliases:"
    end

    test "generates frontmatter for multi-word packages" do
      frontmatter = SkillGenerator.format_skill_frontmatter(:phoenix_live_view, "")

      assert frontmatter =~ "name: phoenix_live_view"
      assert frontmatter =~ "description: Guidance on working with Phoenix Live View"
      refute frontmatter =~ "aliases:"
    end

    test "ignores provided description parameter" do
      frontmatter =
        SkillGenerator.format_skill_frontmatter(
          :ash,
          "A declarative, resource-oriented framework"
        )

      assert frontmatter =~ "description: Guidance on working with Ash"
      refute frontmatter =~ "declarative"
    end
  end

  describe "format_skill_file/3" do
    test "combines frontmatter and content" do
      content = "# Usage Rules\n\nSome rules here"
      result = SkillGenerator.format_skill_file(:ash, "", content)

      assert result =~ "---"
      assert result =~ "name: ash"
      assert result =~ "# Usage Rules"
      assert result =~ "Some rules here"
    end
  end
end
