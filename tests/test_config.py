"""Static checks on the template: agent frontmatter, skill frontmatter, settings.json wiring.

Run: python -m unittest discover -s tests -v
"""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLAUDE = ROOT / ".claude"
MODELS = {"opus", "sonnet", "haiku", "inherit"}
EFFORTS = {"low", "medium", "high", "xhigh", "max"}


def frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    assert m, f"{path.name}: no frontmatter"
    fields = {}
    for line in m.group(1).splitlines():
        key, sep, value = line.partition(":")
        if sep:
            fields[key.strip()] = value.strip()
    return fields


class AgentTest(unittest.TestCase):
    def test_every_agent_pins_name_model_and_effort(self):
        agents = sorted((CLAUDE / "agents").glob("*.md"))
        self.assertEqual(len(agents), 10)
        for path in agents:
            with self.subTest(agent=path.name):
                fm = frontmatter(path)
                self.assertTrue(fm.get("name"))
                self.assertTrue(fm.get("description"))
                self.assertIn(fm.get("model"), MODELS)
                self.assertIn(fm.get("effort"), EFFORTS)

    def test_reviewers_cannot_write(self):
        for name in ("security-reviewer", "explore"):
            tools = frontmatter(CLAUDE / "agents" / f"{name}.md")["tools"]
            self.assertNotIn("Write", tools)
            self.assertNotIn("Edit", tools)


class SkillTest(unittest.TestCase):
    def test_every_skill_has_name_and_description(self):
        skills = sorted((CLAUDE / "skills").glob("*/SKILL.md"))
        self.assertEqual(len(skills), 6)
        for path in skills:
            with self.subTest(skill=path.parent.name):
                fm = frontmatter(path)
                self.assertEqual(fm.get("name"), path.parent.name)
                self.assertTrue(fm.get("description"))


class SettingsTest(unittest.TestCase):
    def setUp(self):
        self.settings = json.loads((CLAUDE / "settings.json").read_text(encoding="utf-8"))

    def test_every_wired_hook_script_exists(self):
        scripts = []
        for groups in self.settings["hooks"].values():
            for group in groups:
                for hook in group["hooks"]:
                    scripts += re.findall(r"\.claude/hooks/([\w.-]+\.ps1)", hook["command"])
        self.assertTrue(scripts)
        for name in scripts:
            self.assertTrue((CLAUDE / "hooks" / name).is_file(), name)

    def test_branch_switching_is_denied(self):
        deny = self.settings["permissions"]["deny"]
        for rule in ("Bash(git checkout:*)", "Bash(git switch:*)", "Bash(git stash:*)"):
            self.assertIn(rule, deny)


if __name__ == "__main__":
    unittest.main()
