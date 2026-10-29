# Notification hook (matchers: permission_prompt, idle_prompt) - plays a distinct Windows sound per type,
# so you notice when Claude waits for you. Adds a toast if the BurntToast module is installed.

param(
    [Parameter(Position = 0)]
    [string]$Type = ""
)

$ErrorActionPreference = 'SilentlyContinue'

$sound = switch ($Type) {
    'permission_prompt' { [System.Media.SystemSounds]::Question }
    'idle_prompt'       { [System.Media.SystemSounds]::Exclamation }
    default             { [System.Media.SystemSounds]::Asterisk }
}
try { $sound.Play() } catch { }

if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
    Import-Module BurntToast -ErrorAction SilentlyContinue
    $title = switch ($Type) {
        'permission_prompt' { "Claude needs permission" }
        'idle_prompt'       { "Claude is waiting for input" }
        default             { "Claude Code" }
    }
    try { New-BurntToastNotification -Text $title -ErrorAction SilentlyContinue } catch { }
}

exit 0
