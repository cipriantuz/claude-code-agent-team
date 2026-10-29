# Parallel sessions on a shared working tree

Several Claude Code sessions often work in the same checkout at once (one fixing a script, one writing docs,
one running a long job). Git's working tree is shared state; the rules below keep sessions from breaking
each other.

## The failure modes

- **Branch switch under another session.** Session A runs `git checkout feature-x`; session B's next edit
  lands on the wrong branch, or B's uncommitted files suddenly belong to a different base.
- **Stash.** `git stash` silently removes another session's work in progress from the tree.
- **Sweep commits.** `git add -A` / `git commit -a` commits another session's half-finished files.
- **Implicit worktree base.** `git worktree add <path> -b feat` without a start point branches from the
  shared checkout's current HEAD, which may be someone else's branch.

## The rules

1. **The shared checkout stays on main.** `.claude/settings.json` denies the commands that would change that:

   ```json
   "deny": ["Bash(git checkout:*)", "Bash(git switch:*)", "Bash(git stash:*)"]
   ```

   A single file is reverted with `git restore <path>`, which touches nothing else.
2. **Commit only your own paths.** `git commit -m "…" -- <path1> <path2>` commits exactly those files, even if
   other files are staged. If a file holds edits from two sessions, stage only your hunks.
3. **Multi-file features go to a worktree with an explicit base:**

   ```bash
   git worktree add ../wt-feature -b feature/name main
   # ... work, test ...
   git -C ../wt-feature merge main                # bring main in, resolve there
   git merge --ff-only feature/name               # in the shared checkout: fast-forward only
   git worktree remove ../wt-feature
   ```

   Fast-forward only means main never gets a merge made in the shared tree.
4. **The pre-commit guard runs on every commit**, including the temporary index that `git commit -- <paths>`
   builds (`tests/test_pre_commit_guard.py` covers that case).
5. **Unattended scripts and deployed services come from main only.** A scheduled script in the shared checkout
   goes live the moment it lands on main, so it is committed on a feature branch until it is ready. A commit
   step in a repo that is pulled with `--ff-only` pushes in the same run or does not commit at all; otherwise
   the next pull diverges.

## Limits

The deny rules match the command prefix Claude Code sees. They stop the agent's own `git checkout`, not a
human in another terminal, not an alias, and not a script that runs git internally. They are a guard rail
against the common mistake, not an access control system.

`branch-guard.ps1` (asks before committing on main) fits a workflow where every change goes through a
branch. With the "small changes straight to main" rule above, leave it out of `settings.json`.
