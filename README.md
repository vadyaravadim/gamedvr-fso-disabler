<div align="center">

# GameDVR & Fullscreen Optimizations Disabler

**Disable Game DVR. Kill Fullscreen Optimizations. One command.**

An open-source PowerShell script that **disables Game DVR / Xbox Game Bar capture** and **Fullscreen Optimizations (FSO)** on Windows 10/11 — two features tweak guides blame for stutter and Game Bar pop-ups mid-game.
Zero install. Zero dependencies. Built-in `.reg` undo.

[![lint](https://img.shields.io/github/actions/workflow/status/vadyaravadim/gamedvr-fso-disabler/lint.yml?label=lint&logo=powershell)](https://github.com/vadyaravadim/gamedvr-fso-disabler/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://docs.microsoft.com/en-us/powershell/)
[![Latest release](https://img.shields.io/github/v/release/vadyaravadim/gamedvr-fso-disabler)](https://github.com/vadyaravadim/gamedvr-fso-disabler/releases)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/gamedvr-fso-disabler?logo=powershell&label=PS%20Gallery)](https://www.powershellgallery.com/packages/gamedvr-fso-disabler)
[![GitHub Stars](https://img.shields.io/github/stars/vadyaravadim/gamedvr-fso-disabler?style=social)](https://github.com/vadyaravadim/gamedvr-fso-disabler/stargazers)

**Part of the [RigPolice Latency Toolbox](https://rigpolice.com/system/latency-toolbox/?utm_source=github&utm_medium=readme&utm_campaign=gamedvr-fso-disabler) — six open-source Windows latency scripts, with what we measured and what we have not yet**

If it works for you, a ⭐ helps others find it.

</div>

---

## Quick Start

**Easiest — one line, in any PowerShell** (it self-elevates):

```powershell
irm https://github.com/vadyaravadim/gamedvr-fso-disabler/releases/latest/download/gamedvr-fso-disabler.ps1 | iex
```

The script downloads itself to `%USERPROFILE%\gamedvr-fso-disabler.ps1` (not a temp folder) on purpose: the `gamedvr_fso_undo_*.reg` rollback file is written next to it and must survive automatic temp cleanup. An existing copy at that path that differs is kept as `.bak`.

**From the PowerShell Gallery**, in PowerShell 7 (`pwsh`):

```powershell
Install-Script gamedvr-fso-disabler
gamedvr-fso-disabler                 # then run it by name (open a NEW PowerShell window first, so the Scripts folder is on PATH)
```

The script self-elevates. Update later with `Update-Script gamedvr-fso-disabler`. Not in the Windows PowerShell 5.1 that comes with Windows: there `Install-Script` wants an admin console and the default execution policy blocks the installed script — use the one-liner instead.

**Or clone:**

```powershell
git clone https://github.com/vadyaravadim/gamedvr-fso-disabler.git
cd gamedvr-fso-disabler
.\Run.bat
```

**Or download the ZIP** (no PowerShell needed): click **Code ▸ Download ZIP** at the top of this page, unzip, then double-click **`Run.bat`** and click **Yes** on the UAC prompt.

Whichever method you use: click **Yes** on the UAC prompt (the script requests admin rights on its own), then **sign out and back in** (or reboot). No parameters, no configuration.

### Running it again

To re-apply after a Windows update resets the values, run it the way you installed it:

| Installed via | Command |
|---------------|---------|
| PowerShell Gallery (PowerShell 7) | `gamedvr-fso-disabler` |
| ZIP or clone | `.\Run.bat` from the script's folder |
| One-liner | `powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\gamedvr-fso-disabler.ps1"` |

**Just checking?** Add `-Status` to any of these commands: it shows every value next to its target and changes nothing, so it needs no admin rights. That is the quick way to see whether an update reset them.

Calling `.\gamedvr-fso-disabler.ps1` directly only works if your execution policy allows scripts — Windows blocks them by default, which is what `Run.bat` and `-ExecutionPolicy Bypass` get around.

## What It Does

1. **Backs up** the previous state of every value it touches to a timestamped `gamedvr_fso_undo_*.reg` file next to the script — **before** changing anything
2. **Disables Game DVR / Game Bar capture** — the machine-wide `AllowGameDVR` policy (the same value gpedit sets) plus the per-user capture toggles
3. **Disables Fullscreen Optimizations** globally via the `GameConfigStore` FSE values — games get classic fullscreen-exclusive behavior

Rollback = double-click the undo file, then sign out/in. Nothing else is touched — Game Mode, Game Bar hotkeys, and encoding settings stay as they are.

## Before & After

Real output from a Windows 11 machine (24H2):

```
===================================
  GAMEDVR + FSO DISABLER vX.Y.Z
===================================

Current state -> target:
  [->] AllowGameDVR = (absent) -> 0  (Game Recording policy (machine-wide kill switch))
  [->] AppCaptureEnabled = 1 -> 0  (Game Bar capture (recording, screenshots))
  [ok] HistoricalCaptureEnabled = 0 -> 0  (Background recording ("Record what happened"))
  [->] GameDVR_Enabled = 1 -> 0  (Game DVR (per-user toggle))
  [->] GameDVR_FSEBehaviorMode = 0 -> 2  (Fullscreen Optimizations (2 = off))
  [->] GameDVR_HonorUserFSEBehaviorMode = 0 -> 1  (Honor the FSE behavior set above)
  [->] GameDVR_DXGIHonorFSEWindowsCompatible = 0 -> 1  (Apply FSE behavior to DXGI (compat path))
  [ok] GameDVR_EFSEFeatureFlags = 0 -> 0  (Enhanced FSE features off)

Undo file saved: E:\gamedvr-fso-disabler\gamedvr_fso_undo_20260718_030740.reg

Applying...
  [OK ] AllowGameDVR = 0
  [OK ] AppCaptureEnabled = 0
  ...

===================================
  DONE
===================================

Applied:
  - Game DVR / Game Bar capture: DISABLED (policy + user values)
  - Fullscreen Optimizations: DISABLED (globally, for this user)

SIGN OUT and back in (or reboot) for all changes to take effect.
Revert any time: double-click the undo file above, then sign out/in.

Useful? A star on GitHub helps others find it: https://github.com/vadyaravadim/gamedvr-fso-disabler
```

> `[ok]` = already at the target value on this machine, `[->]` = will be changed. Values already correct are still recorded in the undo file. If **all** values are already at target, the script changes nothing and writes no undo file.

## Settings Changed

| Key | Value | After | What it controls |
|-----|-------|-------|------------------|
| `HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR` | `AllowGameDVR` | **0** | Windows Game Recording and Broadcasting policy — the documented machine-wide kill switch (what gpedit sets) |
| `HKCU\...\CurrentVersion\GameDVR` | `AppCaptureEnabled` | **0** | Game Bar capture: recording, screenshots, broadcast |
| `HKCU\...\CurrentVersion\GameDVR` | `HistoricalCaptureEnabled` | **0** | Background recording ("Record what happened") |
| `HKCU\System\GameConfigStore` | `GameDVR_Enabled` | **0** | Game DVR per-user toggle |
| `HKCU\System\GameConfigStore` | `GameDVR_FSEBehaviorMode` | **2** | Fullscreen Optimizations behavior (2 = off) |
| `HKCU\System\GameConfigStore` | `GameDVR_HonorUserFSEBehaviorMode` | **1** | Make Windows honor the FSE behavior above |
| `HKCU\System\GameConfigStore` | `GameDVR_DXGIHonorFSEWindowsCompatible` | **1** | Apply the FSE behavior on the DXGI compatibility path |
| `HKCU\System\GameConfigStore` | `GameDVR_EFSEFeatureFlags` | **0** | Enhanced fullscreen-exclusive features off |

All values are DWORD. `AllowGameDVR` and the FSE values are the same ones every "disable Game DVR" / "disable fullscreen optimizations" guide has you set by hand — here they're applied in one run, with an undo file first.

## The Problem: What Game DVR and FSO Do

**Game DVR** is the recording backend of the Xbox Game Bar. With background recording ("Record what happened") on, it records the game continuously so it can save the last moments on demand. On our Windows 11 machine that was already off (the `[ok]` row in the output above), so check **Settings ▸ Gaming ▸ Captures** before you blame it.

**Fullscreen Optimizations** run fullscreen games in a mode [Microsoft describes](https://devblogs.microsoft.com/directx/demystifying-full-screen-optimizations/) as fullscreen exclusive with a quick way back to desktop composition, so overlays and fast Alt-Tab work. Microsoft says almost all players get the same performance as in fullscreen exclusive; players still report stutter or input lag in some titles, which is what the per-game "Disable fullscreen optimizations" checkbox is for. This script applies that behavior globally instead of exe-by-exe.

**What people turn them off for:**

- Frame drops or stutter that disappear when Game Bar capture is off
- "You can't record right now" / Game Bar overlay popping up mid-game
- Input lag or broken frame pacing in games that behave better in true fullscreen

We have not measured the effect of either on frame times yet. Turn them off, compare your own frame-time graph, and undo if nothing changed.

## Verify

After signing back in:

- Press **Win+G** → the capture widget is disabled (Game Bar itself still opens; capture is dead)
- **Settings ▸ Gaming ▸ Captures** → "Record what happened" is off and greyed out by policy
- Or run the script with `-Status` (no admin rights needed): all eight values should show `[ok]`.

## Reverting

Double-click the `gamedvr_fso_undo_*.reg` file saved next to the script, confirm the merge, then sign out and back in. It restores the exact previous state of every value — including deleting values that didn't exist before (like the `AllowGameDVR` policy on a default system).

Ran the script several times? A run that finds nothing to change writes no undo file. If several runs did change values (something re-enabled them in between), apply their undo files newest-to-oldest — only the oldest holds the original state.

## FAQ

### What is Game DVR?

Game DVR is the recording backend of the **Xbox Game Bar** — it powers background recording ("Record what happened"), clips, and screenshots. Background recording is the part that runs while you play: it records continuously so it can save what just happened. On our Windows 11 machine it was off already.

### Does disabling Game DVR increase FPS?

We have not measured it. Turning Game DVR off stops background recording if it was running; on our Windows 11 machine it was off already. It also stops the Game Bar overlay from popping up mid-game.

### What are Fullscreen Optimizations in Windows 11?

A Windows feature that runs fullscreen games in a mode Microsoft describes as **fullscreen exclusive** with a quick way back to desktop composition, so overlays, notifications, and Alt-Tab work seamlessly. Microsoft says almost all players get the same performance as in fullscreen exclusive; players report worse frame pacing or input lag in some titles, and those are the ones people set the per-exe "Disable fullscreen optimizations" checkbox for.

### Should I disable Fullscreen Optimizations?

If your games run flawlessly — leave it. If you see stutter or input lag that vanishes in true fullscreen, disabling FSO is the standard fix. This script sets it globally; the undo file takes you back in one double-click. On the newest Windows 11 builds (24H2+) Microsoft has been reworking windowed/fullscreen presentation, so the win is title- and build-dependent — test your own games.

### Is it safe?

Yes. Every value is a documented policy or a standard Settings-app toggle stored in the registry; the script writes a `.reg` undo file with the exact previous state **before** touching anything. Worst case: double-click the undo file, sign out/in, and you're back to stock.

### Does this uninstall or break Xbox Game Bar?

No. The Game Bar app stays installed and Win+G still opens it — only **capture** (recording, screenshots, background DVR) is disabled. Game Mode is untouched too. If you want the app itself gone, that's `winget uninstall "Xbox Game Bar"` territory, not a registry tweak.

### How is this different from setting it in gpedit / Settings?

It's the same result: `AllowGameDVR = 0` **is** the gpedit policy ("Enables or disables Windows Game Recording and Broadcasting"), and the other values are what the Settings app writes. The script just applies all eight in one run — including on Windows Home, which has no gpedit — and saves an undo file first.

### How is this different from debloaters like Win11Debloat or O&O ShutUp10?

Those flip dozens to hundreds of settings at once. This does **one** focused tweak — Game DVR + FSO — transparently, with a per-run undo file. If you only want this fixed, you don't need to audit a debloater's whole checklist.

### Do the changes survive a reboot? A Windows update?

Reboots — yes, they're plain registry values. Major Windows feature updates occasionally reset per-user gaming settings; if capture comes back after an update, [run the script again](#running-it-again).

### Why does a game still stutter after this?

Then capture wasn't your bottleneck. Next usual suspects in order: GPU driver overlays (GeForce Experience / ReLive), CPU core parking, legacy-mode interrupts, timer resolution — the last three are exactly what the [related utilities](#related) cover.

## Related

- [CPU Parking Disabler](https://github.com/vadyaravadim/cpu-parking-disabler) — disable CPU core parking on Windows 10/11, with the parked-core count shown before and after
- [MSI Mode Utility](https://github.com/vadyaravadim/msi-mode-utility) — enable MSI mode (Message Signaled Interrupts) for GPU, USB, network & audio devices
- [Interrupt Affinity Utility](https://github.com/vadyaravadim/interrupt-affinity-utility) — pin GPU, network, USB & audio interrupts to specific CPU cores (P/E-core aware)
- [Timer Resolution Utility](https://github.com/vadyaravadim/timer-resolution-utility) — set 0.5 ms timer resolution, disable dynamic tick, un-force HPET — with a built-in Sleep(1) benchmark
- [Remove Hidden Devices](https://github.com/vadyaravadim/remove-hidden-devices) — remove ghost / hidden devices left behind by unplugged USB sticks, headsets & dongles cluttering Device Manager

Same idea across the series: one transparent PowerShell script, no binaries, you see exactly what changes.

## License

[MIT](LICENSE) — use at your own risk.

---

<div align="center">

If this helped, consider giving it a ⭐

[Report Issues](https://github.com/vadyaravadim/gamedvr-fso-disabler/issues)

</div>
