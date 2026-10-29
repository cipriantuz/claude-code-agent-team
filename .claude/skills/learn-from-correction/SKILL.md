---
name: learn-from-correction
description: When the owner corrects me on a non-obvious pattern — e.g. says "no, don't do X", "actually we should Y", "you forgot Z again" — capture the correction as a durable rule. Use after any explicit correction, especially repeat ones. Skip for trivial typo fixes or one-off task tweaks.
---

# Learn from a correction

When this skill fires, your job is to capture a correction the owner just made so it survives the conversation and binds future sessions.

## Decide first: durable or transient?

Append a new entry ONLY if the correction is non-obvious AND would re-bite a fresh-context Claude. Skip if:
- The owner is rephrasing a one-off task ("actually rename this file to X")
- The fix is already obvious from reading the codebase
- It's a trivial typo or formatting nudge
- A near-identical entry already exists in `docs/lessons-learned.md` or in your memory directory

## When durable, append to `docs/lessons-learned.md`

Use this exact structure (keep the `---` separators):

```markdown
## YYYY-MM-DD — short imperative title

**Mistake:** one sentence, what I did
**Correction:** one sentence, what the owner said or what should have happened
**Rule for next time:** one sentence, written for a future Claude with no context

---
```

Today's date is in the system context; don't guess.

## Promote to memory if it's a behavior pattern

If the rule is about how the owner wants me to behave (preferences, workflow style, communication tone), ALSO save it as a `feedback` memory (see the memory section of `team-workflow`). `docs/lessons-learned.md` is project-scoped; memory follows the owner across sessions.

## Output

After appending, print one line: `Saved to lessons-learned: <title>`. Don't restate the correction in narrative form — the owner just said it and doesn't need a summary.
