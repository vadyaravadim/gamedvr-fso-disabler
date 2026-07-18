<#
.SYNOPSIS
    Disables Game DVR / Xbox Game Bar capture and Fullscreen Optimizations on Windows 10/11.
.DESCRIPTION
    Turns off Game DVR (Game Bar background capture / recording) via the documented
    AllowGameDVR machine policy plus the per-user GameDVR values, and disables
    Fullscreen Optimizations globally via the GameConfigStore FSE values.

    A .reg undo file with the previous state of every value is written next to
    the script BEFORE any change. Zero external dependencies.
.NOTES
    Sign out and back in (or reboot) for all changes to take effect.
    Revert: double-click the gamedvr_fso_undo_*.reg file, then sign out/in.
    Each undo file is a per-run snapshot: after several runs, apply them
    newest-to-oldest — only the oldest file holds the original state.
.EXAMPLE
    .\gamedvr-fso-disabler.ps1

    Double-click Run.bat, or right-click this file > Run with PowerShell.
    No parameters needed — it elevates itself.
.LINK
    https://github.com/vadyaravadim/gamedvr-fso-disabler
#>
[CmdletBinding()]
param(
    [switch]$Elevated,  # internal: set by the self-elevation relaunch
    [string]$UserSid    # internal: SID of the pre-elevation user (HKCU hive target)
)

$ErrorActionPreference = 'Stop'

# Keep the self-elevated window open so the user can read the output.
function Wait-IfElevatedWindow {
    if ($Elevated) { Read-Host "Press Enter to close" | Out-Null }
}

# Without this, an unhandled error closes the self-elevated window before
# the user can read the message.
trap {
    Write-Host "ERROR: $_" -ForegroundColor Red
    Wait-IfElevatedWindow
    exit 1
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running as Administrator. Requesting elevation..." -ForegroundColor Yellow
    try {
        # Forward the launching user's SID: if UAC elevates to a DIFFERENT admin
        # account, HKCU in the elevated process is that admin's hive — the
        # per-user values would silently land in the wrong profile.
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass',
                     '-File', "`"$PSCommandPath`"", '-Elevated',
                     '-UserSid', $identity.User.Value)
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    } catch {
        Write-Host "ERROR: elevation was refused. Run this script as Administrator." -ForegroundColor Red
    }
    return
}

# Per-user values go to the pre-elevation user's hive when UAC switched accounts.
if ($UserSid -and $UserSid -ne $identity.User.Value) {
    $hkcu = "Registry::HKEY_USERS\$UserSid"
    Write-Host "Elevated as a different account - per-user values go to the launching user's hive (HKEY_USERS\$UserSid)." -ForegroundColor Yellow
} else {
    $hkcu = 'HKCU:'
}

function ConvertTo-RawRegPath([string]$Path) {
    # Provider path -> raw path for the .reg format
    ($Path -replace '^Registry::', '') -replace '^HKCU:', 'HKEY_CURRENT_USER' -replace '^HKLM:', 'HKEY_LOCAL_MACHINE'
}

$gcs = "$hkcu\System\GameConfigStore"
$dvr = "$hkcu\Software\Microsoft\Windows\CurrentVersion\GameDVR"
$pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'

# All values are DWORD. Grouped: Game DVR capture off, then Fullscreen Optimizations off.
$tweaks = @(
    [PSCustomObject]@{ Path = $pol; Name = 'AllowGameDVR';                          Value = 0; Label = 'Game Recording policy (machine-wide kill switch)' }
    [PSCustomObject]@{ Path = $dvr; Name = 'AppCaptureEnabled';                     Value = 0; Label = 'Game Bar capture (recording, screenshots)' }
    [PSCustomObject]@{ Path = $dvr; Name = 'HistoricalCaptureEnabled';              Value = 0; Label = 'Background recording ("Record what happened")' }
    [PSCustomObject]@{ Path = $gcs; Name = 'GameDVR_Enabled';                       Value = 0; Label = 'Game DVR (per-user toggle)' }
    [PSCustomObject]@{ Path = $gcs; Name = 'GameDVR_FSEBehaviorMode';               Value = 2; Label = 'Fullscreen Optimizations (2 = off)' }
    [PSCustomObject]@{ Path = $gcs; Name = 'GameDVR_HonorUserFSEBehaviorMode';      Value = 1; Label = 'Honor the FSE behavior set above' }
    [PSCustomObject]@{ Path = $gcs; Name = 'GameDVR_DXGIHonorFSEWindowsCompatible'; Value = 1; Label = 'Apply FSE behavior to DXGI (compat path)' }
    [PSCustomObject]@{ Path = $gcs; Name = 'GameDVR_EFSEFeatureFlags';              Value = 0; Label = 'Enhanced FSE features off' }
)

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "  GAMEDVR + FSO DISABLER" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Current state
# ============================================================================
Write-Host "Current state -> target:"
foreach ($t in $tweaks) {
    $old = (Get-ItemProperty -Path $t.Path -Name $t.Name -ErrorAction SilentlyContinue).($t.Name)
    $oldText = if ($null -eq $old) { '(absent)' } else { $old }
    $mark = if ($old -eq $t.Value) { 'ok' } else { '->' }
    Write-Host ("  [{0}] {1} = {2} -> {3}  ({4})" -f $mark, $t.Name, $oldText, $t.Value, $t.Label) -ForegroundColor $(if ($old -eq $t.Value) { 'DarkGray' } else { 'Yellow' })
}

# ============================================================================
# Undo file: record the CURRENT state of every value BEFORE changing anything.
# Double-clicking it reverts everything. Value-level on purpose: a "[-key]"
# stanza would also wipe values this tool never wrote (bitrates, hotkeys, ...).
# "=-" deletes a value that did not exist before; reg import may leave an
# empty key behind, which is harmless.
# ============================================================================
# The suffix loop keeps two runs within the same second from clobbering
# each other's undo file.
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$undoFile = Join-Path $PSScriptRoot "gamedvr_fso_undo_$stamp.reg"
$n = 1
while (Test-Path $undoFile) { $undoFile = Join-Path $PSScriptRoot ("gamedvr_fso_undo_{0}_{1}.reg" -f $stamp, $n++) }
$undo = New-Object System.Text.StringBuilder
[void]$undo.AppendLine('Windows Registry Editor Version 5.00')
[void]$undo.AppendLine('')
foreach ($group in ($tweaks | Group-Object Path)) {
    [void]$undo.AppendLine("[$(ConvertTo-RawRegPath $group.Name)]")
    foreach ($t in $group.Group) {
        $old = (Get-ItemProperty -Path $t.Path -Name $t.Name -ErrorAction SilentlyContinue).($t.Name)
        if ($null -eq $old) {
            [void]$undo.AppendLine(('"{0}"=-' -f $t.Name))                       # value was absent -> delete it
        } else {
            [void]$undo.AppendLine(('"{0}"=dword:{1:x8}' -f $t.Name, [int]$old))
        }
    }
    [void]$undo.AppendLine('')
}
Set-Content -Path $undoFile -Value $undo.ToString() -Encoding Unicode
Write-Host ""
Write-Host "Undo file saved: $undoFile" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Apply
# ============================================================================
Write-Host "Applying..."
foreach ($t in $tweaks) {
    if (-not (Test-Path $t.Path)) {
        New-Item -Path $t.Path -Force | Out-Null      # policy key does not exist by default
    }
    New-ItemProperty -Path $t.Path -Name $t.Name -Value $t.Value -PropertyType DWord -Force | Out-Null
    Write-Host ("  [OK ] {0} = {1}" -f $t.Name, $t.Value) -ForegroundColor Green
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "  DONE" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Applied:"
Write-Host "  - Game DVR / Game Bar capture: DISABLED (policy + user values)"
Write-Host "  - Fullscreen Optimizations: DISABLED (globally, for this user)"
Write-Host ""
Write-Host "SIGN OUT and back in (or reboot) for all changes to take effect." -ForegroundColor Green
Write-Host "Revert any time: double-click the undo file above, then sign out/in." -ForegroundColor DarkGray
Wait-IfElevatedWindow
