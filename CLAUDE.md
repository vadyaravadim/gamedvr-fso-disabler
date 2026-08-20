# GameDVR & FSO Disabler

A single self-contained PowerShell script (`gamedvr-fso-disabler.ps1`) that turns off Game DVR / Xbox Game
Bar capture (the `AllowGameDVR` machine policy plus the per-user `GameDVR` values) and Fullscreen
Optimizations (the `GameConfigStore` FSE values) - eight registry values, listed in the `$tweaks` array.
Part of a family of six single-script Windows tuning tools that share this layout: one `.ps1`, `Run.bat`,
`PSScriptAnalyzerSettings.psd1`, and the same three workflows.

## Invariants the undo file depends on

- **The undo `.reg` is value-level, never `[-key]`.** A key-deletion stanza would also wipe values this
  tool never wrote (capture bitrate, hotkeys). A value that did not exist before is recorded as `"name"=-`;
  the empty key `reg import` may leave behind is harmless.
- **A run that changes nothing writes NO undo file.** A second run would otherwise snapshot the
  already-tweaked state, and double-clicking that newest file would "revert" to the tweak instead of the
  original. Do not make undo-file writing unconditional.
- **The original value TYPE is preserved** (`ConvertTo-RegValueText`): a foreign tweaker may have left one
  of these as `REG_SZ` / QWORD / binary, and the revert has to restore what was actually there. The
  target-state check is a strict `[int]` comparison for the same reason - a string `'0'` compares loosely
  equal to `0` but still has to be rewritten as a DWORD.
- **The launching user's SID is forwarded through UAC** (`-UserSid`). If UAC elevates into a different
  administrator account, `HKCU` in the elevated process is that account's hive and the per-user values land
  in the wrong profile. Never simplify this to plain `HKCU:`.
- **A piped run saves the script into the user profile, not `%TEMP%`.** The undo file is written next to
  the script, so it has to sit somewhere that survives automatic temp cleanup.

## The two CI gates

- **`ascii-check.yml` - the .ps1 must be pure ASCII with no BOM.** Both halves are load-bearing: a BOM
  makes `irm | iex` choke on a leading U+FEFF, and non-ASCII in a BOM-less file turns into mojibake when
  Windows PowerShell 5.1 runs it with `-File`. Write `\uXXXX` regex escapes rather than literals; em-dashes
  and typographic quotes are the usual way this reds. Only the `.ps1` is checked - Markdown is free.
- **`lint.yml` - PSScriptAnalyzer over the whole repo, Error + Warning, any finding fails.** Suppressions
  live in `PSScriptAnalyzerSettings.psd1` with the reason written next to each rule. Extend that file with
  a justification instead of adding an inline suppression attribute.

## Release - the tag is the only source of truth

`git tag vX.Y.Z && git push origin vX.Y.Z` runs `release.yml`, which stamps the tag into `.VERSION`, hashes
the script, attests build provenance, creates the GitHub Release and publishes to the PowerShell Gallery.
Nothing ships from a push to `main`.

**Before tagging, move the `## [Unreleased]` bullets in `CHANGELOG.md` into a `## [X.Y.Z] - YYYY-MM-DD`
section and add the compare link at the bottom.** The release job copies exactly that section into the
release body and **fails the release when the tag's section is missing**. This is a gate on purpose, not a
fallback: notes are hand-written because GitHub's `--generate-notes` lists merged PRs, and this repo lands
nearly everything as direct commits to `main`, so it published releases whose whole body was a compare
link.

Write the entries for someone who runs the tool, not for someone reading the diff: what changed on their
machine and why it matters. A fix says what was broken and what it cost them.

Do NOT bump `.VERSION` in the `.ps1` by hand - it is a placeholder the workflow overwrites, and a
hand-edited value that disagrees with the tag would only mislead whoever reads the committed file.
