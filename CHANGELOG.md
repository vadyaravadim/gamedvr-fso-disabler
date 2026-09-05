# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each released section below IS the GitHub Release body for that tag: `release.yml` copies the section
verbatim into the release and fails the release if the tag has no section here.

## [Unreleased]

## [1.0.2] - 2026-09-05

### Changed

- `Run.bat` now waits for a keypress before its window closes, so if the launch itself fails - the
  script blocked or missing next to it - the reason stays on screen instead of the window vanishing.

### Fixed

- The copy a piped `irm ... | iex` run saves into your user profile was written with a UTF-8 BOM, which
  then broke running that saved copy through `irm | iex` again - the parser chokes on the leading byte
  order mark. It is now written without one.

## [1.0.1] - 2026-07-19

### Added

- The tool runs from a one-line `irm ... | iex` command. A piped run has no file on disk, and this tool
  writes its undo file next to the script, so the run saves itself into your user profile first and reruns
  from there - the `.reg` undo lands beside it and survives, which it would not have in `%TEMP%`. An
  existing copy that differs is kept as `.bak` rather than overwritten.
- Published to the PowerShell Gallery: `Install-Script gamedvr-fso-disabler`.
- Every tagged release ships a `SHA256SUMS.txt` alongside the script plus a signed build-provenance
  attestation, so you can verify the file you downloaded is the one the workflow built from this source.

### Fixed

- Non-ASCII characters in the script showed up as mojibake when Windows PowerShell 5.1 ran the file with
  `-File`. The script is now pure ASCII with no BOM, and a CI check keeps it that way: a BOM would break
  `irm | iex`, and non-ASCII in a BOM-less file breaks the 5.1 `-File` path.
- A failed elevation now prints the actual reason and keeps the window open, instead of the console closing
  on an empty screen. Elevation can fail for reasons other than a refused UAC prompt - a disabled UAC
  service, for one - and the old message assumed a refusal.

## [1.0.0] - 2026-07-18

### Added

- First release. Turns off Game DVR / Xbox Game Bar background capture through the documented
  `AllowGameDVR` machine policy plus the per-user `GameDVR` values, and turns off Fullscreen Optimizations
  globally through the `GameConfigStore` FSE values - eight values in total, each printed with its current
  and target state before anything is written. The changes take hold once you sign out and back in.
- Writes a `.reg` undo file next to the script before making any change, holding the previous state of
  every value. Double-clicking the `gamedvr_fso_undo_*.reg` it leaves behind reverts everything. The
  snapshot is value-level rather than whole-key, so reverting cannot wipe settings this tool never wrote -
  your capture bitrate and hotkeys are left alone.
- A run that finds every value already at target changes nothing and writes no undo file, so a repeat run
  cannot leave you with a "revert" file that restores the tweaked state instead of the original.
- Forwards the launching user's SID through the UAC prompt. When UAC elevates into a different
  administrator account, `HKCU` in the elevated process is that other account's hive, and the per-user
  values would have silently landed in the wrong profile.
- Preserves the original value type in the undo file. A value another tweaker left behind as a string or a
  binary blob instead of a DWORD is snapshotted as what it actually was, so the revert restores it exactly.
  A value that was absent before the run is recorded as absent, so reverting deletes it again rather than
  leaving this tool's own DWORD behind.
- Self-elevates through UAC: double-click the bundled `Run.bat` or start the script yourself, and it asks
  for admin rights on its own. It keeps the elevated window open on both success and error, runs on
  Windows 10 and Windows 11, and depends on nothing outside Windows.

[Unreleased]: https://github.com/vadyaravadim/gamedvr-fso-disabler/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/vadyaravadim/gamedvr-fso-disabler/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/vadyaravadim/gamedvr-fso-disabler/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/vadyaravadim/gamedvr-fso-disabler/releases/tag/v1.0.0
