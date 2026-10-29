# Adversarial review and judge panels

The author of a change is the worst judge of it — human or model. The setup separates the roles that write
from the roles that judge, and gives the judges reasons to disagree.

## Review gates

```
architect (read-only) → owner approves design → backend/frontend write → main session probes
UNVERIFIED assumptions on the real system → qa-engineer → security-reviewer (read-only) → merge
→ team-reviewer (only for big features)
```

- **security-reviewer cannot edit.** No Write/Edit tools. It reports findings with an OWASP category, a
  severity and a concrete fix; a developer agent applies the fix and QA adds a regression test. A reviewer
  that edits tends to make the finding disappear instead of making it visible.
- **qa-engineer reviews failure branches, not only the happy path.** A static review of the `except` /
  timeout paths of infrastructure scripts caught, twice in one week, the same class of bug (a generic
  `except` turning "server busy" into "server down") that no normal run would show.
- **The main session probes before QA.** QA and security review code; they cannot know that an external API
  behaves differently from its docs. The developer's report lists those assumptions as UNVERIFIED and the
  main session tests each one against the real system first.
- **team-reviewer is a checkpoint, not a habit.** It runs on request or after features over 5 code files.
  A retrospective once cost 238k tokens, more than the QA pass it reviewed.

## Judge panels

For decisions where one answer from one context is too narrow, the main session runs a panel:

1. Launch N agents (typically 3–4) **in parallel**, read-only, with the same material but a **different
   imposed angle** each (e.g. "find the failure mode", "argue for the simplest option", "check against the
   spec", "assume the input is hostile"). Each knows the others exist and that its value is in being
   different, not in being safe.
2. Each returns a fixed, short format (verdict + top findings with evidence), so answers can be compared.
3. The main session — or one separate judging pass that did not produce any candidate — compares them,
   keeps what is backed by evidence, and records why.

The same idea applied to code review: running `qa-engineer` and `security-reviewer` in parallel on the same
diff gives two independent lists; disagreements are the interesting part.

This template ships no dedicated panel agent: a panel is just parallel Agent calls with different prompts,
orchestrated by the main session.
