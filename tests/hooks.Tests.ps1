# Tests for the Claude Code hooks in .claude/hooks (no framework needed; Windows PowerShell 5.1 or pwsh).
# Each case feeds the hook the JSON Claude Code would send on stdin and checks exit code / stdout / stderr.
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File tests/hooks.Tests.ps1
# Fake secrets are assembled by string concatenation so this file never matches a secret scanner.

$ErrorActionPreference = 'Continue'
$hooks = Join-Path (Split-Path -Parent $PSScriptRoot) '.claude/hooks'
$shell = (Get-Process -Id $PID).Path
$script:failures = 0
$script:passed = 0

function Invoke-Hook([string]$name, [string]$stdin, [string]$cwd = $PWD.Path) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $shell
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $hooks $name)`""
    $psi.WorkingDirectory = $cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($stdin)
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    [pscustomobject]@{ Code = $p.ExitCode; Out = $out.Trim(); Err = $err.Trim() }
}

function Check([string]$label, [bool]$ok, $result) {
    if ($ok) { $script:passed++; Write-Host "PASS  $label" }
    else { $script:failures++; Write-Host "FAIL  $label (exit=$($result.Code) out=[$($result.Out)] err=[$($result.Err)])" }
}

function Edit-Json([string]$path) { @{ tool_name = 'Edit'; tool_input = @{ file_path = $path } } | ConvertTo-Json -Compress }
function Bash-Json([string]$cmd) { @{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress }

function New-TempRepo {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("hooktest-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    Push-Location $dir
    git init -q -b main 2>$null
    if ($LASTEXITCODE -ne 0) { git init -q; git symbolic-ref HEAD refs/heads/main }
    git config user.email test@example.invalid; git config user.name test; git config commit.gpgsign false
    Set-Content -Path a.txt -Value 'start'
    git add a.txt; git commit -q -m start
    Pop-Location
    $dir
}

# --- block-protected-files.ps1 ---
foreach ($blocked in @('C:/repo/.env', 'C:/repo/.env.local', 'C:/repo/.env.production', 'C:/repo/web/package-lock.json',
                       'C:/repo/yarn.lock', 'C:/repo/pnpm-lock.yaml', 'C:/repo/App/App.csproj.user')) {
    $r = Invoke-Hook 'block-protected-files.ps1' (Edit-Json $blocked)
    Check "block-protected-files blocks $blocked" ($r.Code -eq 2 -and $r.Err.Length -gt 0) $r
}
foreach ($allowed in @('C:/repo/.env.example', 'C:/repo/.env.template', 'C:/repo/src/Program.cs', 'C:/repo/package.json')) {
    $r = Invoke-Hook 'block-protected-files.ps1' (Edit-Json $allowed)
    Check "block-protected-files allows $allowed" ($r.Code -eq 0) $r
}
$r = Invoke-Hook 'block-protected-files.ps1' 'not json'
Check "block-protected-files lets malformed input through" ($r.Code -eq 0) $r

# --- secret-scan.ps1 ---
$repo = New-TempRepo
try {
    $fakeKey = 'AK' + 'IA' + ('Q' * 16)
    Set-Content -Path (Join-Path $repo 'cfg.txt') -Value "key = $fakeKey"
    git -C $repo add cfg.txt
    $r = Invoke-Hook 'secret-scan.ps1' (Bash-Json 'git commit -m "add config"') $repo
    Check "secret-scan blocks git commit with a staged fake AWS key" ($r.Code -eq 2 -and $r.Err -match 'AKIA') $r
    $r = Invoke-Hook 'secret-scan.ps1' (Bash-Json 'ls -la') $repo
    Check "secret-scan ignores commands other than git commit" ($r.Code -eq 0) $r
    Set-Content -Path (Join-Path $repo 'cfg.txt') -Value 'key = read-from-environment'
    git -C $repo add cfg.txt
    $r = Invoke-Hook 'secret-scan.ps1' (Bash-Json 'git commit -m "add config"') $repo
    Check "secret-scan allows a clean commit" ($r.Code -eq 0) $r
} finally { Remove-Item -Recurse -Force $repo }

# --- branch-guard.ps1 ---
$repo = New-TempRepo
try {
    $r = Invoke-Hook 'branch-guard.ps1' (Bash-Json 'git commit -m x') $repo
    Check "branch-guard asks before a commit on main" ($r.Code -eq 0 -and $r.Out -match '"permissionDecision":"ask"') $r
    $r = Invoke-Hook 'branch-guard.ps1' (Bash-Json 'git status') $repo
    Check "branch-guard ignores commands other than git commit" ($r.Code -eq 0 -and $r.Out -eq '') $r
    git -C $repo branch -q feature/x
    git -C $repo symbolic-ref HEAD refs/heads/feature/x
    $r = Invoke-Hook 'branch-guard.ps1' (Bash-Json 'git commit -m x') $repo
    Check "branch-guard stays silent on a feature branch" ($r.Code -eq 0 -and $r.Out -eq '') $r
} finally { Remove-Item -Recurse -Force $repo }

# --- dotnet-build-check.ps1 / tsc-check.ps1 (cheap paths only: no SDK needed) ---
$noProject = Join-Path ([IO.Path]::GetTempPath()) ("hooktest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $noProject | Out-Null
try {
    $r = Invoke-Hook 'dotnet-build-check.ps1' (Edit-Json (Join-Path $noProject 'readme.md'))
    Check "dotnet-build-check ignores non-C# files" ($r.Code -eq 0 -and $r.Out -eq '') $r
    $r = Invoke-Hook 'dotnet-build-check.ps1' (Edit-Json (Join-Path $noProject 'Loose.cs'))
    Check "dotnet-build-check skips a .cs file with no .csproj above it" ($r.Code -eq 0 -and $r.Out -eq '') $r
    $r = Invoke-Hook 'tsc-check.ps1' (Edit-Json (Join-Path $noProject 'types.d.ts'))
    Check "tsc-check ignores .d.ts files" ($r.Code -eq 0 -and $r.Out -eq '') $r
    $r = Invoke-Hook 'tsc-check.ps1' (Edit-Json (Join-Path $noProject 'app.ts'))
    Check "tsc-check skips a .ts file with no tsconfig.json above it" ($r.Code -eq 0 -and $r.Out -eq '') $r
} finally { Remove-Item -Recurse -Force $noProject }

Write-Host ""
Write-Host "$($script:passed) passed, $($script:failures) failed"
if ($script:failures -gt 0) { exit 1 }
exit 0
