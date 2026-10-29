"""Git pre-commit guard: refuses secrets, huge files and leftover conflict markers.

It only looks at what goes into the commit (the index, including the temporary index that
`git commit -- <paths>` builds):
  - added lines that look like a known token (GitHub, Anthropic, OpenAI, AWS, Google, Slack, private keys);
  - files over 50 MB (Git LFS stages only a small pointer, so LFS files are not affected);
  - leftover conflict markers (7x '<' or 7x '>' at the start of a line).
Conscious bypass, only for a verified false positive: git commit --no-verify.
An internal error lets the commit through (the guard must never block work because of its own bug).
Standard library only.
"""
from __future__ import annotations

import re
import subprocess
import sys

LIMIT_MB = 50
PATTERNS = [
    ("GitHub token", re.compile(r"ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82}|gho_[A-Za-z0-9]{36}")),
    ("Anthropic key", re.compile(r"sk-ant-[A-Za-z0-9_\-]{20,}")),
    ("OpenAI key", re.compile(r"sk-(?:proj|svcacct)-[A-Za-z0-9_\-]{40,}")),
    ("AWS access key", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("Google API key", re.compile(r"AIza[A-Za-z0-9_\-]{35}")),
    ("Slack token", re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}")),
    ("private key", re.compile(r"-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----")),
]
CONFLICT = re.compile(r"^(?:<{7}|>{7})(?: |$)")
BINARY = re.compile(r"\.(png|jpe?g|gif|webp|mp4|mov|wav|mp3|zip|7z|exe|dll|pdf|safetensors|gguf|bin|pt|onnx)$", re.I)


def git(*args: str) -> str:
    return subprocess.run(["git", "-c", "core.quotepath=off", *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace", check=True).stdout


def problems() -> list[str]:
    found = []
    for path in git("diff", "--cached", "--name-only", "-z", "--diff-filter=AM").split("\0"):
        if not path:
            continue
        size = int(git("cat-file", "-s", f":{path}").strip() or 0)
        if size > LIMIT_MB * 1024 * 1024:
            found.append(f"{path}: {size / 1048576:.0f} MB (over {LIMIT_MB} MB; use Git LFS or keep it out of git)")
    current = ""
    for line in git("diff", "--cached", "-U0", "--no-color", "--diff-filter=AM").splitlines():
        if line.startswith("+++ "):
            current = line[6:] if line.startswith("+++ b/") else ""
            continue
        if not line.startswith("+") or not current or BINARY.search(current):
            continue
        text = line[1:]
        for name, pattern in PATTERNS:
            if pattern.search(text):
                found.append(f"{current}: {name}")
        if CONFLICT.match(text):
            found.append(f"{current}: conflict marker")
    return sorted(set(found))


def main() -> int:
    try:
        found = problems()
    except Exception as e:  # noqa: BLE001 - the guard must not block work because of its own failure
        print(f"pre-commit guard: could not check ({e}); letting the commit through", file=sys.stderr)
        return 0
    if not found:
        return 0
    print("pre-commit guard: commit refused", file=sys.stderr)
    for item in found:
        print(f"  - {item}", file=sys.stderr)
    print("Remove the secret / file from the commit. Only for a verified false positive: git commit --no-verify",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
