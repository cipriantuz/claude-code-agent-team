# PreToolUse hook (matcher: Bash) - before Claude runs `git commit`, scans the staged files for secrets.
# Any other Bash command passes untouched. Exit 2 = block; the reason on stderr is shown to Claude.
# Second line of defence: the git pre-commit guard (githooks/) also runs for commits made outside Claude.

$ErrorActionPreference = 'Continue'

try {
    $jsonInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}
$command = [string]$jsonInput.tool_input.command
if ($command -notmatch '\bgit\b[^|;&]*\bcommit\b') { exit 0 }

$patterns = @(
    'AKIA[0-9A-Z]{16}',                    # AWS access key
    'ghp_[A-Za-z0-9]{36}',                 # GitHub PAT (classic)
    'github_pat_[A-Za-z0-9_]{82}',         # GitHub PAT (fine-grained)
    'sk-ant-[A-Za-z0-9\-_]{20,}',          # Anthropic API key
    'sk-proj-[A-Za-z0-9\-_]{40,}',         # OpenAI project key
    'sk-svcacct-[A-Za-z0-9\-_]{40,}',      # OpenAI service account key
    'AIza[A-Za-z0-9_\-]{35}',              # Google API key
    'xox[baprs]-[A-Za-z0-9-]+',            # Slack token
    '-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----',
    'password\s*[:=]\s*["\x27][^"\x27\s]{6,}["\x27]'   # hard-coded password literal
)

$staged = git diff --cached --name-only --diff-filter=AM 2>$null
if (-not $staged) { exit 0 }

$hits = @()
foreach ($file in $staged) {
    if (-not (Test-Path $file)) { continue }
    if ($file -match '\.(gguf|bin|safetensors|jpg|png|pdf|zip|exe|dll|css|scss|less|min\.js|map|svg|woff2?|ttf|otf|eot)$') { continue }
    if ($file -match '(^|/)(node_modules|\.venv|dist|build)/') { continue }
    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    foreach ($pat in $patterns) {
        if ($content -match $pat) { $hits += "$file -> $pat" }
    }
}

if ($hits.Count -gt 0) {
    [Console]::Error.WriteLine("Secret scan blocked the commit. Suspicious patterns:`n" + ($hits -join "`n"))
    exit 2
}
exit 0
