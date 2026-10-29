# PreToolUse hook (matcher: Bash) - asks for confirmation before Claude runs `git commit` on main/master.
# Optional: use it when every change goes through a feature branch. Drop it if small changes are
# committed straight to main (see docs/parallel-sessions.md).

$ErrorActionPreference = 'Continue'

try {
    $jsonInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}
$command = [string]$jsonInput.tool_input.command
if ($command -notmatch '\bgit\b[^|;&]*\bcommit\b') { exit 0 }

$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
if ($LASTEXITCODE -ne 0) { exit 0 }

if ($branch -in @('master', 'main')) {
    @{
        hookSpecificOutput = @{
            hookEventName            = "PreToolUse"
            permissionDecision       = "ask"
            permissionDecisionReason = "About to commit on '$branch'. Confirm only if the change is tested and meant to land on $branch."
        }
    } | ConvertTo-Json -Depth 5 -Compress
}
exit 0
