# PostToolUse hook (matcher: Edit|Write) - TypeScript type check after a .ts/.tsx file is edited.
# Non-blocking: on failure it hands the first type errors back to Claude as context.

$ErrorActionPreference = 'Continue'

try {
    $jsonInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}

$filePath = $jsonInput.tool_input.file_path
if (-not $filePath -or $filePath -notmatch '\.(ts|tsx)$') { exit 0 }
if ($filePath -match '\.d\.ts$') { exit 0 }
if ($filePath -match '(node_modules|dist|build|\.next)[/\\]') { exit 0 }

# Find the nearest tsconfig.json walking up
$dir = Split-Path -Parent $filePath
$tsconfig = $null
while ($dir -and (Test-Path $dir)) {
    $candidate = Join-Path $dir 'tsconfig.json'
    if (Test-Path $candidate) { $tsconfig = $candidate; break }
    $parent = Split-Path -Parent $dir
    if ($parent -eq $dir) { break }
    $dir = $parent
}
if (-not $tsconfig) { exit 0 }

function Write-Context([string]$text) {
    @{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $text } } |
        ConvertTo-Json -Depth 5 -Compress
}

$projectDir = Split-Path -Parent $tsconfig
$tscFailedToRun = $false
$tscExit = 0

Push-Location $projectDir
try {
    $tscOutput = & npx --no-install tsc --noEmit -p $tsconfig 2>&1 | Out-String
    $tscExit = $LASTEXITCODE
    if ($tscExit -ne 0 -and $tscOutput -match 'could not determine|not found|No such file|MODULE_NOT_FOUND') {
        $tscFailedToRun = $true
    }
} catch {
    $tscFailedToRun = $true
    $tscOutput = $_.Exception.Message
}
Pop-Location

if ($tscFailedToRun) {
    Write-Context "tsc-check could not run tsc in $projectDir (TypeScript not installed locally? 'npm install --save-dev typescript'). File edited: $filePath. Type check skipped."
    exit 0
}
if ($tscExit -eq 0) { exit 0 }

$errorLines = ($tscOutput -split "`n" | Where-Object { $_ -match 'error TS' } | Select-Object -First 10) -join "`n"
Write-Context "tsc --noEmit failed in $projectDir after editing $filePath. Type errors:`n$errorLines"
exit 0
