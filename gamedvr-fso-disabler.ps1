<#PSScriptInfo

.VERSION 1.0.0

.GUID 87a31f64-6a9a-4a19-8b74-4a634e74fb59

.AUTHOR vadyaravadim

.COMPANYNAME

.COPYRIGHT

.TAGS Windows Windows10 Windows11 Gaming GameDVR GameBar FullscreenOptimizations FSO Performance Stutter Tweak Registry

.LICENSEURI https://github.com/vadyaravadim/gamedvr-fso-disabler/blob/main/LICENSE

.PROJECTURI https://github.com/vadyaravadim/gamedvr-fso-disabler

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

.PRIVATEDATA

#>

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
    Each undo file is a per-run snapshot (a run that changes nothing writes
    no undo file); after several runs, apply them newest-to-oldest - only
    the oldest file holds the original state.
.EXAMPLE
    .\gamedvr-fso-disabler.ps1

    Double-click Run.bat, or right-click this file > Run with PowerShell.
    No parameters needed - it elevates itself.
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
    # Under `irm | iex` this runs inside the user's own session, where `exit`
    # would close their console - rethrow so only the piped script stops.
    if ($PSCommandPath) { exit 1 }
    break
}

# Launched via `irm <url> | iex` - no file on disk. The undo .reg is written
# next to the script, so a stable path is required: save the script to the
# user profile (not TEMP - the undo file must survive automatic temp cleanup)
# and rerun it from there (the rerun handles elevation).
if (-not $PSCommandPath) {
    # The piped text is not recoverable from inside iex ($MyInvocation there
    # holds the caller's command line, not the script body) - download the
    # script.
    try {
        $body = Invoke-RestMethod 'https://raw.githubusercontent.com/vadyaravadim/gamedvr-fso-disabler/main/gamedvr-fso-disabler.ps1' -TimeoutSec 30
    } catch {
        Write-Host "ERROR: could not download the script ($($_.Exception.Message)). Check your internet connection, or save the script to a file and run it from there." -ForegroundColor Red
        return
    }
    $saved = Join-Path $env:USERPROFILE 'gamedvr-fso-disabler.ps1'
    if ((Test-Path $saved) -and ([IO.File]::ReadAllText($saved) -cne $body)) {
        Copy-Item $saved "$saved.bak" -Force
        Write-Host "Existing $saved differs - previous copy kept as $saved.bak" -ForegroundColor Yellow
    }
    # UTF8Encoding($false) = no BOM: a BOM would break a later `irm | iex` of
    # the saved copy and violates the ASCII/no-BOM invariant the repo enforces.
    [IO.File]::WriteAllText($saved, $body, [Text.UTF8Encoding]::new($false))
    Write-Host "Script saved to: $saved (the undo file will be written next to it)" -ForegroundColor Cyan
    powershell -NoProfile -ExecutionPolicy Bypass -File $saved
    # The rerun's exit code stays in $LASTEXITCODE for scripted callers.
    return
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running as Administrator. Requesting elevation..." -ForegroundColor Yellow
    try {
        # Forward the launching user's SID: if UAC elevates to a DIFFERENT admin
        # account, HKCU in the elevated process is that admin's hive - the
        # per-user values would silently land in the wrong profile.
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass',
                     '-File', "`"$PSCommandPath`"", '-Elevated',
                     '-UserSid', $identity.User.Value)
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs
    } catch {
        # Not always a refusal (UAC service disabled, ...) - show the real cause.
        Write-Host "ERROR: elevation failed ($($_.Exception.Message)). Run this script as Administrator." -ForegroundColor Red
        Read-Host "Press Enter to close" | Out-Null
    }
    return
}

# Per-user values go to the pre-elevation user's hive when UAC switched accounts.
if ($UserSid -and $UserSid -ne $identity.User.Value) {
    $hkcu = "Registry::HKEY_USERS\$UserSid"
    Write-Host "Elevated as a different account - per-user values go to the launching user's hive (HKEY_USERS\$UserSid)." -ForegroundColor Yellow
    Write-Host "NOTE: re-importing the undo file's HKEY_LOCAL_MACHINE section will also require admin rights." -ForegroundColor Yellow
} else {
    $hkcu = 'HKCU:'
}

function ConvertTo-RawRegPath([string]$Path) {
    # Provider path -> raw path for the .reg format
    ($Path -replace '^Registry::', '') -replace '^HKCU:', 'HKEY_CURRENT_USER' -replace '^HKLM:', 'HKEY_LOCAL_MACHINE'
}

# .reg text for a value, preserving its original type: a foreign tweaker may
# have left one of these as REG_SZ / QWORD / binary instead of the expected DWORD.
function ConvertTo-RegValueText($Value) {
    if ($Value -is [int])    { return 'dword:{0:x8}' -f $Value }
    if ($Value -is [long])   { return 'hex(b):' + (([BitConverter]::GetBytes($Value) | ForEach-Object { '{0:x2}' -f $_ }) -join ',') }
    if ($Value -is [byte[]]) { return 'hex:' + (($Value | ForEach-Object { '{0:x2}' -f $_ }) -join ',') }
    if ($Value -is [string]) { return '"{0}"' -f ($Value -replace '\\', '\\' -replace '"', '\"') }
    throw "cannot snapshot a value of type $($Value.GetType().Name) into the undo file"
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

Write-Host "Current state -> target:"
foreach ($t in $tweaks) {
    $old = (Get-ItemProperty -Path $t.Path -Name $t.Name -ErrorAction SilentlyContinue).($t.Name)
    # strict [int] check: a foreign REG_SZ '0' compares loosely equal to 0
    # but must still be rewritten as a DWORD
    $ok = ($old -is [int]) -and ($old -eq $t.Value)
    $t | Add-Member NoteProperty Old $old
    $t | Add-Member NoteProperty Ok $ok
    $oldText = if ($null -eq $old) { '(absent)' } else { $old }
    $mark = if ($ok) { 'ok' } else { '->' }
    Write-Host ("  [{0}] {1} = {2} -> {3}  ({4})" -f $mark, $t.Name, $oldText, $t.Value, $t.Label) -ForegroundColor $(if ($ok) { 'DarkGray' } else { 'Yellow' })
}

# Nothing to change -> no undo file: a repeat-run snapshot would record the
# already-tweaked state, and double-clicking that newest file would silently
# "revert" to it instead of the original.
if (-not ($tweaks | Where-Object { -not $_.Ok })) {
    Write-Host ""
    Write-Host "All values already at target - nothing to do, no undo file written." -ForegroundColor Green
    Wait-IfElevatedWindow
    return
}

# Undo file: record the CURRENT state of every value BEFORE changing anything.
# Double-clicking it reverts everything. Value-level on purpose: a "[-key]"
# stanza would also wipe values this tool never wrote (bitrates, hotkeys, ...).
# "=-" deletes a value that did not exist before; reg import may leave an
# empty key behind, which is harmless.
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
        if ($null -eq $t.Old) {
            [void]$undo.AppendLine(('"{0}"=-' -f $t.Name))                       # value was absent -> delete it
        } else {
            [void]$undo.AppendLine(('"{0}"={1}' -f $t.Name, (ConvertTo-RegValueText $t.Old)))
        }
    }
    [void]$undo.AppendLine('')
}
Set-Content -Path $undoFile -Value $undo.ToString() -Encoding Unicode
Write-Host ""
Write-Host "Undo file saved: $undoFile" -ForegroundColor Cyan
Write-Host ""

Write-Host "Applying..."
foreach ($t in $tweaks) {
    if (-not (Test-Path $t.Path)) {
        New-Item -Path $t.Path -Force | Out-Null      # policy key does not exist by default
    }
    New-ItemProperty -Path $t.Path -Name $t.Name -Value $t.Value -PropertyType DWord -Force | Out-Null
    Write-Host ("  [OK ] {0} = {1}" -f $t.Name, $t.Value) -ForegroundColor Green
}

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
