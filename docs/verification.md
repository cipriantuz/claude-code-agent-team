# Verification standard

The rule: **"verified" = the command that was run + 1–3 lines of its real output.** Everything else is
labeled: READ (only looked at) or NOT VERIFIED (not run). It applies to the main session and to every agent
report.

## Why it exists

Agents write confident reports. Failures seen in practice, each caught later by a real run:

- A report said "done" while the delivered files were truncated; the agent had checked its own pasted copy,
  not the file on disk.
- A "diacritics preserved" test was an OR of plain-ASCII words, so it passed on corrupted text too.
- A function under test was copied into the test instead of loaded from the real script; the test passed
  while the script was broken.
- Contract tests asserted one hand-written dict against another; a snake_case/camelCase mismatch passed 200+
  green tests until a real browser run.

## The checks

1. **Run it on the delivered artifact**, not a copy, a paste, or an equivalent snippet.
2. **A check must be able to fail.** Run it once against a known-bad input (break the code, feed a fake
   secret, corrupt the encoding) and see it go red. This repository does that for its own tests: the guard
   tests fail when the size limit or a pattern is broken, the hook tests fail when the hook stops blocking.
3. **Verify at the right layer.** A browser for UI, a raw socket for HTTP edge cases (test clients normalise
   `..` in paths), a real end-to-end run for a new pipeline branch. An agent without the right tool says so.
4. **External APIs: probe the assumptions.** Code against an external API or UI comes with a list of the
   author's assumptions about the real system, marked UNVERIFIED. The main session probes each one on the real
   system before QA and security review. In one feature, the real probes caught five bugs that the offline
   test suite had passed.
5. **Docs about behavior carry `file:line`.** The main session spot-checks three claims plus every number.
   "Consistent" in a report is not evidence.
6. **Big features get independent QA.** More than 5 files or user-facing behavior → `qa-engineer` verifies,
   not the session that wrote or orchestrated the code.
