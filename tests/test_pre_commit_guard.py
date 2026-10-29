"""Pre-commit guard tests: each test builds a throwaway repo with the hook installed.

Run: python -m unittest discover -s tests -v
All "secrets" below are fake and assembled by string concatenation, so this file itself never
matches a secret scanner.
"""
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOKS = Path(__file__).resolve().parent.parent / "githooks"

# One fake value per guard pattern (7 patterns).
FAKE_SECRETS = {
    "GitHub token": "gh" + "p_" + "a" * 36,
    "Anthropic key": "sk-" + "ant-" + "b" * 30,
    "OpenAI key": "sk-" + "proj-" + "c" * 45,
    "AWS access key": "AK" + "IA" + "A" * 16,
    "Google API key": "AI" + "za" + "d" * 35,
    "Slack token": "xo" + "xb-" + "1" * 12,
    "private key": "-----BEGIN " + "RSA PRIVATE" + " KEY-----",
}


def git(cwd, *args, ok=True):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if ok:
        assert r.returncode == 0, r.stderr
    return r


class PreCommitGuardTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.repo = Path(self.tmp) / "r"
        git(self.tmp, "init", "-q", str(self.repo))
        for key, value in (("user.email", "test@example.invalid"), ("user.name", "test"),
                           ("core.autocrlf", "false"), ("commit.gpgsign", "false")):
            git(self.repo, "config", key, value)
        hooks = self.repo / ".git" / "hooks"
        for name in ("pre-commit", "pre_commit_guard.py"):
            shutil.copy(HOOKS / name, hooks / name)
        hook = hooks / "pre-commit"
        hook.chmod(hook.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        self.write("a.txt", "start\n")
        git(self.repo, "add", "a.txt")
        git(self.repo, "commit", "-q", "-m", "start")

    def tearDown(self):
        def unlock(func, path, _exc):  # git objects are read-only on Windows
            os.chmod(path, stat.S_IWRITE)
            func(path)
        if sys.version_info >= (3, 12):
            shutil.rmtree(self.tmp, onexc=unlock)
        else:
            shutil.rmtree(self.tmp, onerror=unlock)

    def write(self, name, text):
        (self.repo / name).write_text(text, encoding="utf-8", newline="\n")

    def commit(self, *paths):
        return git(self.repo, "commit", "-q", "-m", "x", *paths, ok=False)

    def test_clean_commit_is_allowed(self):
        self.write("b.py", "print('hello')\n")
        git(self.repo, "add", "b.py")
        self.assertEqual(self.commit().returncode, 0)

    def test_each_secret_pattern_is_refused(self):
        for label, value in FAKE_SECRETS.items():
            with self.subTest(label=label):
                self.write("cfg.txt", f"VALUE = '{value}'\n")
                git(self.repo, "add", "cfg.txt")
                r = self.commit()
                self.assertNotEqual(r.returncode, 0, label)
                self.assertIn(label, r.stderr)
                git(self.repo, "reset", "-q", "cfg.txt")

    def test_commit_with_paths_checks_the_temporary_index(self):
        """`git commit -- <paths>` builds a temporary index; the guard must see it."""
        self.write("a.txt", "start\n" + FAKE_SECRETS["Anthropic key"] + "\n")
        r = self.commit("--", "a.txt")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Anthropic key", r.stderr)

    def test_file_over_50_mb_is_refused(self):
        with open(self.repo / "big.dat", "wb") as f:
            f.seek(51 * 1024 * 1024)
            f.write(b"x")
        git(self.repo, "add", "big.dat")
        r = self.commit()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("over 50 MB", r.stderr)

    def test_conflict_markers_are_refused(self):
        self.write("c.md", "<" * 7 + " HEAD\none\n" + "=" * 7 + "\ntwo\n" + ">" * 7 + " branch\n")
        git(self.repo, "add", "c.md")
        r = self.commit()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("conflict marker", r.stderr)

    def test_old_secret_in_history_does_not_block_a_new_commit(self):
        self.write("old.txt", FAKE_SECRETS["AWS access key"] + "\n")
        git(self.repo, "add", "old.txt")
        git(self.repo, "commit", "-q", "--no-verify", "-m", "old")
        self.write("old.txt", FAKE_SECRETS["AWS access key"] + "\nnew line\n")
        git(self.repo, "add", "old.txt")
        self.assertEqual(self.commit().returncode, 0)


if __name__ == "__main__":
    unittest.main()
