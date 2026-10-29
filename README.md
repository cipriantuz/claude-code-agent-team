# Claude Code agent team

This is the [Claude Code](https://docs.claude.com/en/docs/claude-code) setup I use every day, cleaned up into a
template you can reuse. I built it because a single general-purpose agent is expensive, reviews its own work,
and will commit secrets or switch branches under a parallel session if nothing stops it. I usually have several
Claude Code sessions working in the same repository at once, which is why the checkout stays on main and
branch switches are denied.

The main session acts as a project manager and hands the work to a team of subagents. The agents that write
the code aren't the ones that judge it, and each role runs on the cheapest model that does it well. Where a
prompt rule isn't enough, a hard guard backs it up.

The template has nine specialized subagents plus a read-only search agent (each pinned to its own model and
reasoning effort), six skills, safety hooks, permission rules for several sessions sharing one working tree,
and a git pre-commit guard.

## The team and the review gates

```mermaid
flowchart TD
    Owner([You]) --> PM[Main session = Project Manager<br/>CLAUDE.md]
    PM -->|design| ARCH[software-architect<br/>opus · max · read-only]
    ARCH -->|you approve the design| PM
    PM -->|implement| BE[backend-developer<br/>opus · high]
    PM -->|implement| FE[frontend-developer<br/>opus · high]
    PM -->|deploy / CI| OPS[devops-engineer<br/>opus · high]
    PM -.->|search| EXP[Explore<br/>haiku · high · read-only]
    PM -.->|research| RES[research-analyst<br/>opus · medium]
    PM -.->|docs| TW[technical-writer<br/>opus · low]
    BE & FE & OPS --> PROBE{{Gate 1: PM probes UNVERIFIED<br/>assumptions on the real system}}
    PROBE --> QA{{Gate 2: qa-engineer<br/>opus · medium}}
    QA --> SEC{{Gate 3: security-reviewer<br/>opus · max · read-only}}
    SEC --> GUARD{{Gate 4: pre-commit guard<br/>secrets · >50 MB · conflict markers}}
    GUARD --> MAIN[(main)]
    MAIN -.->|big features only| REV[team-reviewer<br/>opus · medium]
    REV -.->|memory + rule updates| PM
```

Underneath, hooks and permission rules guard the tool calls: protected files can't be edited, `git commit` is
scanned for secrets, C#/TypeScript edits get a build/type check, and `git checkout` / `switch` / `stash` are denied.

## What's inside

| Path | What |
|---|---|
| `CLAUDE.md` | Rulebook template for the main session: delegation, verification, git, token economics |
| `.claude/agents/` | 10 subagents: architect, backend, frontend, QA, security reviewer, DevOps, research, technical writer, team reviewer, Explore |
| `.claude/skills/` | `team-workflow`, `learn-from-correction`, `team-retrospective`, `aspnet-controller`, `aspnet-feature-bundle`, `ef-migration` |
| `.claude/hooks/` | `block-protected-files`, `secret-scan`, `dotnet-build-check`, `tsc-check`, `notify-windows`, optional `branch-guard` (PowerShell) |
| `.claude/settings.json` | Hook wiring + allow/deny permission rules |
| `githooks/` | Git pre-commit guard (Python stdlib + a small sh wrapper) |
| `tests/` | Guard tests, hook tests, static config tests |
| `docs/` | Design notes |

## Quickstart (about 5 minutes)

```bash
# 1. Copy the template into your repository
cp -r claude-code-agent-team/.claude claude-code-agent-team/githooks your-repo/
cp claude-code-agent-team/CLAUDE.md your-repo/        # or merge it into your existing CLAUDE.md

# 2. Turn on the pre-commit guard (needs Python 3.8+ on PATH)
cd your-repo
git config core.hooksPath githooks

# 3. Edit the stack lists in CLAUDE.md and .claude/agents/*.md to match your defaults
# 4. Start Claude Code in the repo; /agents lists the team
```

The hooks are PowerShell scripts, called as `powershell -File "$CLAUDE_PROJECT_DIR/.claude/hooks/…"`. On
macOS or Linux, install PowerShell 7 and replace `powershell` with `pwsh` in `.claude/settings.json`, or drop
the hooks you don't need (`notify-windows` only works on Windows).

## Tests and CI

```bash
python -m unittest discover -s tests -v                                   # guard + config tests
powershell -NoProfile -ExecutionPolicy Bypass -File tests/hooks.Tests.ps1 # hook tests (Windows)
```

- `tests/test_pre_commit_guard.py` builds a throwaway repo for each test and installs the hook in it. The hook
  has to refuse each of the 7 secret patterns, a 51 MB file and conflict markers, and to catch a secret staged
  through the temporary index of `git commit -- <paths>`. And it has to allow a clean commit and not re-flag an old secret that's
  already in history.
- `tests/hooks.Tests.ps1` feeds each hook the JSON that Claude Code sends and checks the exit code and output
  (22 cases).
- `tests/test_config.py` checks that every agent pins a valid model and effort, the reviewers have no write
  tools, every wired hook script exists, and the branch-switching deny rules are present.
- `.github/workflows/ci.yml` runs the Python tests on Ubuntu and Windows, and the hook tests under Windows
  PowerShell 5.1 and PowerShell 7.

The guard runs on this repository's own commits too, so all fake secrets in the tests are built by string
concatenation and the repository itself never matches a secret scanner.

## Design decisions

- **Model and effort per role, pinned in the frontmatter.** I use max effort only for the architect and the
  security reviewer (rare calls, high stakes), and Haiku only for read-only search.
  → [docs/model-routing.md](docs/model-routing.md)
- **"Verified" means a command and its real output**, and the check has to be able to fail.
  → [docs/verification.md](docs/verification.md)
- **Writers and judges are separate.** The security reviewer can't edit. Decisions that need more than one
  view go to a panel of parallel agents, each given a different angle.
  → [docs/adversarial-review.md](docs/adversarial-review.md)
- **Several sessions, one working tree.** The checkout stays on main, commits name their paths, and features
  go to worktrees and merge fast-forward only. → [docs/parallel-sessions.md](docs/parallel-sessions.md)
- **Cost ≈ turns × context.** So there's no polling, scheduled checks run as scripts, and subagents keep raw
  data out of the main context. → [docs/token-economics.md](docs/token-economics.md)
- **Two layers against secrets.** The `secret-scan` hook stops Claude's own `git commit`, and the git guard
  stops every commit, including a human's. If the guard itself hits an internal error, it lets the commit
  through: a broken guard must not block work.

## Limitations

- My own workspace runs 12 agents and 8 skills. This template keeps the 10 general-purpose agents and 6
  skills, and leaves out 2 agents and 2 skills written for a personal project.
- The hooks are PowerShell and were developed on Windows. On macOS/Linux you need `pwsh` and the command
  change above.
- The deny rules match the command prefixes Claude Code sees. They don't stop a human, an alias, or a script
  that runs git internally.
- Pattern-based secret detection misses secrets with no recognizable prefix (generic passwords, custom
  tokens). Use a dedicated scanner and your host's push protection as well.
- If Python is missing, the guard doesn't run and the commit goes through (by design). `git commit --no-verify`
  also bypasses it.
- The hook JSON contract (`hookSpecificOutput`, exit code 2 = block) follows the Claude Code docs at the time
  of writing. The tests check the scripts' outputs, not a live Claude Code session.
- The ASP.NET skills assume Minimal APIs, EF Core and xUnit.

## How I built it

I built this with AI coding agents (Claude Code), and they wrote most of the code and prompts. My part was the
architecture (the roles, the model routing, the gates), the review process and the verification.

I don't take an agent's "done" at face value, so this is what I checked and how:

- Guard and config tests: I ran `python -m unittest discover -s tests` and 11 tests passed. As a negative control I
  raised the size limit to 100 MB and broke one pattern. The suite then failed on exactly those two cases.
- Hooks: I ran `tests/hooks.Tests.ps1` under Windows PowerShell 5.1 and 22/22 passed. As a negative control I
  changed `block-protected-files` to exit 0, and 7 cases failed.
- `dotnet-build-check`: I ran it by hand against a real project with the .NET 10 SDK. A clean file produced no
  output, and a syntax error returned the compiler errors. That run also exposed a bug in the original hook
  (it read a stale exit code and reported a clean build as failed), which is fixed here.
- Settings and CI: I checked that `settings.json` loads as JSON, that every hook it wires exists
  (`tests/test_config.py`), and that `ci.yml` parses as YAML. The first GitHub Actions run passed on 29.10.2026
  (guard and config tests on Ubuntu and Windows, PowerShell hook tests on Windows).
- Content: before publishing, I searched the repository and its git history for personal paths, hostnames,
  tokens and private project names.

## License

MIT, see [LICENSE](LICENSE).
