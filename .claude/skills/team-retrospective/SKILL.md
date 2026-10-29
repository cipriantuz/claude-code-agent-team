---
name: team-retrospective
description: Trigger when the user says "retrospective", "monthly report", "what did we learn", "team retro" — collect git history, agent memories and lessons, and produce a structured retrospective document.
---

# Team Retrospective Generator

## Step 1 — Confirm the period

Ask the owner which period to cover. Default: the last 30 days.

Resolve it to absolute dates (e.g. `2026-04-10` to `2026-05-10`) for all git commands.

## Step 2 — Collect data

Run in parallel:

```bash
# Commits in the period
git log --oneline --all --since="{start-date}" --until="{end-date}"

# Files changed (activity heatmap)
git log --name-only --since="{start-date}" --format="" | sort | uniq -c | sort -rn | head -20
```

Read these files:
- `docs/lessons-learned.md` (if it exists)
- All `.claude/agent-memory/**/*.md`

## Step 3 — Synthesize

Produce `retrospectives/{YYYY-MM}.md` with this structure:

```markdown
# Retrospective {YYYY-MM}
Period: {start-date} → {end-date}

## Delivered (top 5)
- {feature/task}: {one-line description}

## Wins (3 things that worked exceptionally)
- {win}: {why it worked}

## Friction points (3 issues + resolution)
- {issue}: {what was done about it}

## New rules adopted
- {rule}: added to {agent or CLAUDE.md}

## Token economy (estimate)
- {what the data shows about turns × context; "insufficient data" if nothing is traceable}

## Recommendations for next month (top 3)
1. {recommendation}
```

## Step 4 — Review and commit

Show the owner the file path and suggest:
```bash
git add retrospectives/{YYYY-MM}.md
git commit -m "retro: {YYYY-MM} retrospective" -- retrospectives/{YYYY-MM}.md
```

Do NOT commit automatically — the owner decides.

## Rules

- Token economy section: if data is unavailable, write "insufficient data"
- Keep the document factual — no invented wins or issues
- If `docs/lessons-learned.md` does not exist, skip that source silently
- The retrospective must not exceed 150 lines — summarize, don't transcribe
