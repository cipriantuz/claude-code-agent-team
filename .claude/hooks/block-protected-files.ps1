# PreToolUse hook (matcher: Edit|Write) - blocks direct edits of protected files.
# Blocks: package-lock.json, yarn.lock, pnpm-lock.yaml, *.csproj.user, .env* (except .env.example/.sample/.template).
# Exit 2 = block; the reason on stderr is shown to Claude.

$ErrorActionPreference = 'Continue'

try {
    $jsonInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}

$filePath = $jsonInput.tool_input.file_path
if (-not $filePath) { exit 0 }

$leaf = Split-Path -Leaf $filePath
$reason = $null

switch -Wildcard ($leaf) {
    'package-lock.json' { $reason = "package-lock.json should only change via 'npm install' / 'npm uninstall'. Run the package manager instead of editing the lock file." }
    'yarn.lock'         { $reason = "yarn.lock should only change via 'yarn add' / 'yarn remove'. Run the package manager instead." }
    'pnpm-lock.yaml'    { $reason = "pnpm-lock.yaml should only change via 'pnpm add' / 'pnpm remove'. Run the package manager instead." }
    '*.csproj.user'     { $reason = "*.csproj.user files are per-user Visual Studio settings and should not be edited or committed. Edit the .csproj instead." }
}

# .env files hold secrets: block all of them except the safe templates.
if (-not $reason -and ($leaf -like '.env*') -and ($leaf -notmatch '^\.env\.(example|sample|template)$')) {
    $reason = ".env files (.env, .env.local, .env.production, ...) contain secrets and must not be edited by Claude. Use .env.example for templates and ask the owner to set the values."
}

if ($reason) {
    [Console]::Error.WriteLine($reason)
    exit 2
}
exit 0
