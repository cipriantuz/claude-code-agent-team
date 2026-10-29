# Token economics

**Cost ≈ turns × context.** Every turn re-sends the whole conversation, so a long session with many small
turns costs far more than the same work in fewer turns or in a fresh context. Almost every rule below
follows from that.

## Rules

- **No polling.** A long job is one blocking command, or a background command that notifies on exit. A check
  every few seconds multiplies the full context by the number of checks.
- **Scheduled checks are scripts, not in-session loops.** An in-session cron/loop re-reads the whole session on
  every tick: two such checks once cost 673k tokens. The OS scheduler runs a script that sends an alert; if
  the check needs a model, it starts `claude -p` in a fresh session.
- **Delegate to keep raw data out of the main context.** Research with many web searches, broad code searches
  (`Explore`) and multi-file implementation run in subagents; the main session gets a ≤15-line report.
- **Do small things yourself.** Delegating a 3-line edit costs a whole subagent context for nothing.
- **Unrelated task → fresh context.** Save state to memory or a file and `/clear`.
- **Pin model and effort per agent** (see `model-routing.md`). Built-in agents inherit the session settings,
  which is how cheap tasks end up running on the most expensive configuration.
- **Short status output.** Tools and scripts the agent calls often print one line on success, details only on
  failure.
- **Expensive runs: probe small first.** A cheap, low-resolution or partial run validates the inputs; the
  full run happens once.
- **Compaction headroom.** Auto-compaction triggers at the window size minus a reserve; set the window so that
  compaction happens before the context becomes the dominant cost.
- **`claude -p` in pipelines: report tokens and time, not USD.** On a subscription, `total_cost_usd` is a list
  price, not a bill.

## Checkpoint reviews

A full team retrospective once cost 238k tokens, more than the QA pass it reviewed. `team-reviewer` therefore
runs only on request or after a big feature (more than 5 code files).
