---
name: team-workflow
description: Detailed workflow rules, agent team structure (model and effort per agent), and the lessons that shaped them. Use when planning multi-agent tasks or onboarding the team to a new project.
---

# Team Workflow — Complete Reference

## Agent team structure

The main session is the **Project Manager**. It delegates to the subagents in `.claude/agents/`:

| Agent | Model · effort | When to use |
|---|---|---|
| software-architect | opus · max | System design, tech stack, architecture decisions |
| security-reviewer | opus · max | OWASP review before merging auth, payments, uploads, user input, external APIs |
| research-analyst | opus · medium | Web research, documentation and paper analysis, technology comparisons |
| qa-engineer | opus · medium | Tests, code review, verification |
| team-reviewer | opus · medium | On request or at the end of a big feature (>5 code files); updates memories and rules |
| backend-developer | opus · high | Server-side code, APIs, databases, business logic |
| frontend-developer | opus · high | UI/UX, React, HTML/CSS/JS, client-side code |
| devops-engineer | opus · high | Docker, CI/CD, deployment, infrastructure |
| technical-writer | opus · low | Documentation, README, guides |
| Explore | haiku · high | Read-only broad code search (overrides the built-in Explore) |

Model and effort are pinned in each agent's frontmatter (the source of truth). Max effort only for
software-architect and security-reviewer: rarely called, high stakes. Haiku only for Explore: a read-only
search that reports `path:line` evidence, where a cheap model at high effort is good enough. The built-in
general-purpose and Plan agents inherit the session's model and effort, so delegate only to the agents above.
Rationale: `docs/model-routing.md`.

## Memory system

Each agent owns a memory subdirectory under `.claude/agent-memory/<agent-name>/` (`memory: project` in the
frontmatter). Always write to YOUR own subdirectory, never to another agent's, and always by absolute path:
the working directory can silently drift into a project subdirectory across tool calls.

Memory types:
- **user** — the owner's role, goals, preferences
- **feedback** — guidance on what to avoid or keep doing (from a correction OR a confirmation)
- **project** — current initiatives, deadlines, constraints (relative dates converted to absolute YYYY-MM-DD)
- **reference** — pointers to external resources

Before saving, check whether a related memory exists and update it instead of creating a duplicate.

**Do NOT save to memory:**
- Code patterns, conventions, architecture, file paths (derive them from the current code)
- Git history or who-changed-what (use `git log` / `git blame`)
- Debugging recipes (the fix is in the code, the context in the commit message)
- Ephemeral task details or in-progress work
- Anything already in CLAUDE.md

## Lessons (from checkpoint reviews)

- **Commit discipline in a shared working tree.** When several sessions or agents work in the same tree,
  the PM stages only the files named in the delegating agent's own report — never `git add -A` /
  `git commit -a` — or another session's work in progress gets swept into an unrelated commit.
- **A phase is "done" only after real verification at its layer** — a browser for UI, a raw socket for HTTP
  edge cases (test clients normalise `..` and give false negatives on path traversal), a live run for
  pipelines. An agent without the right tool for that layer says so explicitly ("NOT E2E verified") and
  never implies full verification from unit tests + build alone.
- **Contract/response-shape tests call the real endpoint/serializer**, never assert a hand-written dict
  against another hand-written dict — that pattern let a snake_case/camelCase contract bug pass 200+ green
  tests until a real browser run caught it.
- **A new pipeline branch wired through a new endpoint needs one REAL end-to-end run**, not just mocked-worker
  unit tests: the endpoint's write path and the worker's read path can disagree on a shared field's meaning
  (e.g. "thread alive" read as "job running"). Verify a shared field's actual semantics against every consumer.
- **A global setting tuned on one consumer is validated on all of them** (or becomes a per-consumer
  override from the start).
- **Resource budget gates need a measured overhead buffer**, tuned after a real benchmark, not an a-priori
  estimate.
- **Worktree base explicit, deploy only from main.** `git worktree add <path> -b <branch> main`: without the
  start point, the branch inherits whatever HEAD the shared checkout has. Deployed services are updated from
  main only, or the branch is merged in the same cycle.
- **Adversarial review of failure branches.** A static QA review of the `except`/timeout paths of
  infrastructure scripts caught, twice in one week, a bug a normal run would never show (a generic `except`
  turned "server busy" into "server down").
- **`claude -p` in pipelines: count tokens, not USD.** On a subscription, `total_cost_usd` is a list price.
  Clean the inherited session environment (`CLAUDE_CODE_*`, effort variables) before spawning it.

## New project rule

Before writing any code on a new project, the **software-architect** MUST:
1. Analyze the project requirements
2. Evaluate whether the preferred stack (ASP.NET Core, React, MSSQL, Redis, SignalR) is the right fit
3. If yes — proceed with the preferred stack and explain briefly why it fits
4. If no — propose alternatives with clear justification (performance, ecosystem, cost, etc.)
5. Get the owner's approval before starting implementation
