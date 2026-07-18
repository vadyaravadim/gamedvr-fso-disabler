<div align="center">

# GameDVR & Fullscreen Optimizations Disabler

**Disable Game DVR. Kill Fullscreen Optimizations. One command.**

An open-source PowerShell script that **disables Game DVR / Xbox Game Bar capture** and **Fullscreen Optimizations (FSO)** on Windows 10/11 — the two background features most often behind stutters, overlay pop-ups, and capture-related frame drops.
Zero install. Zero dependencies. Built-in `.reg` undo.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://docs.microsoft.com/en-us/powershell/)
![GitHub Stars](https://img.shields.io/github/stars/vadyaravadim/gamedvr-fso-disabler?style=social)

</div>

---

## Quick Start

**Easiest — download & double-click:**

1. Click **Code ▸ Download ZIP** at the top of this page, then unzip.
2. Double-click **`Run.bat`**.
3. Click **Yes** on the UAC prompt (the script requests admin rights on its own).
4. **Sign out and back in** (or reboot).

**One-liner** instead (in any PowerShell — it self-elevates):

```powershell
irm https://raw.githubusercontent.com/vadyaravadim/gamedvr-fso-disabler/main/gamedvr-fso-disabler.ps1 -OutFile "$env:USERPROFILE\gamedvr-fso-disabler.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\gamedvr-fso-disabler.ps1"
```

The script is saved to your user profile (not a temp folder) on purpose: the `gamedvr_fso_undo_*.reg` rollback file is written next to it and must survive automatic temp cleanup.

**Or clone:**

```powershell
git clone https://github.com/vadyaravadim/gamedvr-fso-disabler.git
cd gamedvr-fso-disabler
.\Run.bat
```

No parameters, no configuration. Run and done.

## What It Does

1. **Backs up** the previous state of every value it touches to a timestamped `gamedvr_fso_undo_*.reg` file next to the script — **before** changing anything
2. **Disables Game DVR / Game Bar capture** — the machine-wide `AllowGameDVR` policy (the same value gpedit sets) plus the per-user capture toggles
3. **Disables Fullscreen Optimizations** globally via the `GameConfigStore` FSE values — games get classic fullscreen-exclusive behavior

Rollback = double-click the undo file, then sign out/in. Nothing else is touched — Game Mode, Game Bar hotkeys, and encoding settings stay as they are.

## Before & After

Real output from a Windows 11 machine (24H2):

```
===================================
  GAMEDVR + FSO DISABLER
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
SIGN OUT and back in (or reboot) for all changes to take effect.
```

> `[ok]` = already at the target value on this machine, `[->]` = will be changed. Values already correct are still recorded in the undo file.

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

## The Problem: Why Game DVR and FSO Cause Stutters

**Game DVR** keeps a capture pipeline warm behind every game so the Game Bar can record "what happened." That costs memory bandwidth and GPU time even when you never record — and on weaker systems it shows up as frame drops and stutter. Microsoft's own performance guidance for capture is clear: recording competes with the game for resources.

**Fullscreen Optimizations** replace classic fullscreen-exclusive mode with an optimized borderless mode so overlays and fast Alt-Tab work. On many systems it's fine; on others it adds input latency or breaks frame pacing in specific titles — which is why the per-game "Disable fullscreen optimizations" checkbox exists. This script applies that behavior globally instead of exe-by-exe.

**Symptoms this addresses:**

- Frame drops or stutter that disappear when Game Bar capture is off
- "You can't record right now" / Game Bar overlay popping up mid-game
- Input lag or broken frame pacing in games that behave better in true fullscreen

## Verify

After signing back in:

- Press **Win+G** → the capture widget is disabled (Game Bar itself still opens; capture is dead)
- **Settings ▸ Gaming ▸ Captures** → "Record what happened" is off and greyed out by policy
- Or check the values directly:

```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name AllowGameDVR
Get-ItemProperty 'HKCU:\System\GameConfigStore' -Name GameDVR_FSEBehaviorMode
```

`AllowGameDVR` should be `0`, `GameDVR_FSEBehaviorMode` should be `2`.

## Reverting

Double-click the `gamedvr_fso_undo_*.reg` file saved next to the script, confirm the merge, then sign out and back in. It restores the exact previous state of every value — including deleting values that didn't exist before (like the `AllowGameDVR` policy on a default system).

Ran the script several times? Undo files are per-run snapshots — apply them newest-to-oldest; only the oldest holds the original state.

## FAQ

### What is Game DVR?

Game DVR is the recording backend of the **Xbox Game Bar** — it powers background recording ("Record what happened"), clips, and screenshots. To do that it keeps capture infrastructure active while you play, whether or not you ever press record.

### Does disabling Game DVR increase FPS?

On systems where the capture pipeline is active it removes its overhead — users typically see fewer frame drops and less stutter rather than a higher average FPS. On a strong system with capture already idle, the difference can be near zero. It also stops the Game Bar overlay from popping up mid-game.

### What are Fullscreen Optimizations in Windows 11?

A Windows feature that silently replaces classic **fullscreen-exclusive** mode with an optimized borderless-windowed mode, so overlays, notifications, and Alt-Tab work seamlessly. Most games run fine with it; some get worse frame pacing or higher input latency — those are the titles people set the per-exe "Disable fullscreen optimizations" checkbox for.

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

Reboots — yes, they're plain registry values. Major Windows feature updates occasionally reset per-user gaming settings; if capture comes back after an update, run the script again.

### Why does a game still stutter after this?

Then capture wasn't your bottleneck. Next usual suspects in order: GPU driver overlays (GeForce Experience / ReLive), CPU core parking, legacy-mode interrupts, timer resolution — the last three are exactly what the [related utilities](#related) cover.

## Related

- [CPU Parking Disabler](https://github.com/vadyaravadim/cpu-parking-disabler) — disable CPU core parking on Windows 10/11 to fix micro-stutters and input lag
- [MSI Mode Utility](https://github.com/vadyaravadim/msi-mode-utility) — enable MSI mode (Message Signaled Interrupts) for GPU, USB, network & audio devices to cut DPC latency and input lag
- [Interrupt Affinity Utility](https://github.com/vadyaravadim/interrupt-affinity-utility) — pin GPU, network, USB & audio interrupts to specific CPU cores (P/E-core aware) to tame DPC latency
- [Timer Resolution Utility](https://github.com/vadyaravadim/timer-resolution-utility) — set 0.5 ms timer resolution, disable dynamic tick, un-force HPET — with a built-in Sleep(1) benchmark

Same idea across all five: one transparent PowerShell script, built-in rollback.

## License

[MIT](LICENSE) — use at your own risk.

---

<div align="center">

If this fixed your stutters, consider giving it a ⭐

[Report Issues](https://github.com/vadyaravadim/gamedvr-fso-disabler/issues)

</div>
