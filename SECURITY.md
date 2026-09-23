# Security Policy

## Reporting a Vulnerability

Please report security issues **privately** via
[GitHub Security Advisories](https://github.com/vadyaravadim/gamedvr-fso-disabler/security/advisories/new)
— not through a public issue.

Expect a first response within 7 days. If a fix is warranted, it ships as a new
tagged release and the advisory is published once the fix is available.

## Supported Versions

Only the latest release receives fixes. Older tags are left as-is — update to the
newest version before reporting.

## Scope

This script runs **with administrator rights** and writes eight registry values:
the `AllowGameDVR` policy under `HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR`
and the Game DVR / Fullscreen Optimizations values in the launching user's hive.
That is its intended purpose, not a vulnerability.

In scope:

- The self-elevation path (`irm | iex` saving to `%USERPROFILE%` and re-running
  from there) — e.g. a way to make it execute attacker-controlled content
- The launching user's SID forwarded through UAC — e.g. a way to make the
  per-user values land in a hive other than the one that started the script
- The saved-copy / `.bak` handling — e.g. a path that overwrites an unrelated file
- The undo file (`gamedvr_fso_undo_*.reg`) — e.g. a registry state that makes the
  script write a `.reg` touching keys or values it never changed
- The release pipeline — checksums, provenance, or the PowerShell Gallery package
  not matching the tagged source

Out of scope:

- Requiring admin rights, or the UAC prompt
- Needing to sign out and back in for the change to take effect — documented in
  [Quick Start](README.md#quick-start)
- Win+G still opening the Game Bar — only capture is disabled, documented in the
  [FAQ](README.md#does-this-uninstall-or-break-xbox-game-bar)
- A Windows feature update resetting the values — documented in the
  [FAQ](README.md#do-the-changes-survive-a-reboot-a-windows-update), and
  reversible per [Reverting](README.md#reverting)
- Importing an undo `.reg` file you edited by hand

## Verifying a Release

Each release publishes `SHA256SUMS.txt` and Sigstore build provenance. Verify a
download before running it:

```powershell
Get-FileHash .\gamedvr-fso-disabler.ps1 -Algorithm SHA256
```

Compare the hash against the one in the corresponding
[release](https://github.com/vadyaravadim/gamedvr-fso-disabler/releases).

The hash only proves the file matches the release page. The provenance proves the
file was built by this repository's `release.yml` from the tagged commit - check it
with the [GitHub CLI](https://cli.github.com/):

```powershell
gh attestation verify .\gamedvr-fso-disabler.ps1 -R vadyaravadim/gamedvr-fso-disabler
```
