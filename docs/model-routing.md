# Model routing per role

Every subagent pins `model` and `effort` in its frontmatter. The frontmatter is the source of truth; the
table in `.claude/skills/team-workflow/SKILL.md` mirrors it.

| Role | Model | Effort | Why |
|---|---|---|---|
| software-architect | opus | max | Rarely called, decisions are expensive to undo. Read-only tools + web. |
| security-reviewer | opus | max | Rarely called, a missed finding is the costliest failure. Read-only by design. |
| backend-developer | opus | high | Writes most of the code; needs depth on async, data access, auth. |
| frontend-developer | opus | high | Same reasoning for UI state, accessibility, API integration. |
| devops-engineer | opus | high | Config mistakes surface late (deploy time); worth the extra reasoning. |
| qa-engineer | opus | medium | Called often; tests and review are well-structured work. |
| research-analyst | opus | medium | Breadth matters more than depth; runs in its own context to keep raw search results out of the main session. |
| team-reviewer | opus | medium | Occasional meta-review; judgment, not deep reasoning. |
| technical-writer | opus | low | Clear prose from material that already exists. |
| Explore | haiku | high | Read-only search that must return `path:line` evidence; a small model at high effort locates code well enough. |

## Rules behind the table

- **Max effort is reserved for two roles.** In the owner's measurements, max effort cost about 2.7× high,
  while high/medium/low differed much less. It pays only where a call is rare and a mistake is expensive.
- **Haiku only where the output is checkable.** Explore returns locations, not judgments; the main session
  reads the cited lines before acting. A snapshot comparison the owner used (October 2026) put Haiku at high
  effort roughly on par with Sonnet at low effort on an aggregate benchmark, at about a fifth of the price.
  Re-check with current numbers before copying the choice.
- **No delegation to built-in general-purpose / Plan agents.** They inherit the session's model and effort, so
  a cheap task delegated from an expensive session runs at the expensive setting. The project-level
  `explore.md` overrides the built-in Explore for the same reason.
- **Read-only where review is the job.** security-reviewer, software-architect and Explore have no Write/Edit
  tools: a reviewer that can edit tends to "fix" a finding instead of reporting it, and the fix then skips review.

## Adapting it

Change the stack lists in the agent prompts, keep the frontmatter fields, and re-run
`python -m unittest discover -s tests` — `tests/test_config.py` checks that every agent pins a valid model
and effort.
