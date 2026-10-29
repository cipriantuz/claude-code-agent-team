# PostToolUse hook (matcher: Edit|Write) - runs `dotnet build` after a C# file is edited.
# Non-blocking: on failure it hands the first errors back to Claude as context; it never blocks the edit.

$ErrorActionPreference = 'Continue'

try {
    $jsonInput = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {
    exit 0
}

$filePath = $jsonInput.tool_input.file_path
if (-not $filePath -or $filePath -notmatch '\.cs$') { exit 0 }

# Skip generated files
if ($filePath -match '(obj|bin)[/\\]' -or $filePath -match 'Migrations[/\\]') { exit 0 }

# Find the nearest .csproj walking up
$dir = Split-Path -Parent $filePath
$csproj = $null
while ($dir -and (Test-Path $dir)) {
    $found = Get-ChildItem -Path $dir -Filter '*.csproj' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $csproj = $found.FullName; break }
    $parent = Split-Path -Parent $dir
    if ($parent -eq $dir) { break }
    $dir = $parent
}
if (-not $csproj) { exit 0 }

function Write-Context([string]$text) {
    @{ hookSpecificOutput = @{ hookEventName = "PostToolUse"; additionalContext = $text } } |
        ConvertTo-Json -Depth 5 -Compress
}

# Internal timeout (25 s) so a slow SDK/restore never hangs the hook.
$hookTimeoutSeconds = 25
$job = Start-Job -ScriptBlock {
    param($proj)
    & dotnet build $proj --nologo --verbosity quiet 2>&1
    "DOTNET_EXIT=$LASTEXITCODE"
} -ArgumentList $csproj

if (-not (Wait-Job -Job $job -Timeout $hookTimeoutSeconds)) {
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Write-Context "dotnet build hit the hook timeout (${hookTimeoutSeconds}s) on $csproj - likely an SDK issue or a missing restore. File edited: $filePath. Build check skipped."
    exit 0
}

$buildOutput = Receive-Job -Job $job | Out-String
if ($buildOutput -match 'DOTNET_EXIT=0') { exit 0 }

$errorLines = ($buildOutput -split "`n" | Where-Object { $_ -match 'error' -and $_ -notmatch 'DOTNET_EXIT' } | Select-Object -First 10) -join "`n"
Write-Context "dotnet build failed for $csproj after editing $filePath. Errors:`n$errorLines"
exit 0
