# GameDVR & FSO Disabler

A single self-contained PowerShell script (`gamedvr-fso-disabler.ps1`) that turns off Game DVR / Xbox Game
Bar capture (the `AllowGameDVR` machine policy plus the per-user `GameDVR` values) and Fullscreen
Optimizations (the `GameConfigStore` FSE values) - eight registry values, listed in the `$tweaks` array.
Part of a family of six single-script Windows tuning tools that share this layout: one `.ps1`, `Run.bat`,
`PSScriptAnalyzerSettings.psd1`, and two thin workflows, `ci.yml` and `release.yml`, that call the family's
shared pipeline in `vadyaravadim/latency-toolbox-ci`.

**`-Status` skips elevation on purpose** - it only reads, and a UAC prompt for a read-only check is what
makes people stop checking. Unelevated, `HKCU` is the launching user's own hive, so `-UserSid` is not
needed there. The `irm | iex` rerun forwards `-Status`; dropping it would turn a read-only request into a
full elevated run that writes.

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

## The CI gates

The gates and the release job live in `.github/workflows/pipeline.yml` of `vadyaravadim/latency-toolbox-ci`,
not here: `ci.yml` runs it on every push and pull request, `release.yml` from a dispatch. Change a gate there.

**`main` moves only to a commit whose `ci` passed on a branch.** Its ruleset requires `ci / psanalyzer`,
`ci / ascii`, `ci / pester (5.1)` and `ci / pester (runner)` from GitHub Actions, so a commit made on `main`
is rejected. Push the branch, wait for `ci`, then merge it into `main` (`--no-ff` works while the branch is
up to date with `main`) and push; push a commit made on `main` to a branch first (`git push origin
main:<branch>`). A pin bump that renames one of these checks needs the new name in the ruleset before it is
pushed to `main`. The preview leg is not required: it only warns.

- **The ASCII gate - every tracked `.ps1` must be pure ASCII with no BOM.** Both halves are load-bearing: a
  BOM makes `irm | iex` choke on a leading U+FEFF, and non-ASCII in a BOM-less file turns into mojibake when
  Windows PowerShell 5.1 runs it with `-File`. Write `\uXXXX` regex escapes rather than literals; em-dashes
  and typographic quotes are the usual way this reds. Only `.ps1` files are checked - Markdown is free.
- **The lint gate - PSScriptAnalyzer over the whole repo, Error + Warning, any finding fails.** Suppressions
  live in `PSScriptAnalyzerSettings.psd1` with the reason written next to each rule; add a justified
  exclusion there instead of an inline suppression attribute. The file is the family's: lint fails unless it
  is byte-identical to the one in `vadyaravadim/latency-toolbox-ci` at the pinned commit, so change it there
  and copy it into all six repos. Lint also fails unless `ci.yml` and `release.yml` pin `latency-toolbox-ci`
  to the full SHA of the commit the run uses. It also checks syntax and .NET types against Windows
  PowerShell 5.1 (`PSUseCompatibleSyntax`/`PSUseCompatibleTypes`). The type check knows APIs only up to .NET
  Core 3.1, so a newer one such as `[Convert]::ToHexString` passes lint and only a test running under 5.1
  would catch it. `PSUseCompatibleCommands` stays off: it flagged every Pester 5 parameter against the
  Pester 3.4 built into 5.1.
- **The Pester gate runs every tracked `*.Tests.ps1` under Windows PowerShell 5.1 and the runner's `pwsh`,
  and both legs block the release.** `tests/gamedvr-fso-disabler.Tests.ps1` loads single functions from the
  script's syntax tree and runs the `irm | iex` rerun against a stub script, so it never touches this
  machine's settings; keep new tests that way, contributors run them on their own PCs. Test code stays
  5.1-safe: `Run.bat` and the elevated relaunch always run 5.1.

## Release - the newest CHANGELOG section is the version

`gh workflow run release.yml` (or Actions > release > Run workflow) on `main` releases the newest `## [X.Y.Z]`
section of `CHANGELOG.md`: it gates that commit, stamps the version into `.VERSION`, hashes the script,
attests build provenance, publishes to the PowerShell Gallery and, last, creates the GitHub Release, which
creates the `vX.Y.Z` tag at that commit. A run from any other branch fails at the `release` environment before
the release job's first step, so nothing is written. Nothing ships from a push to `main`, and no tag exists
until every gate has passed.

- **The `irm | iex` URL is `releases/latest/download/gamedvr-fso-disabler.ps1` - in the README AND in the
  script's bootstrap download, never `raw.githubusercontent.com/.../main`.** That is what keeps the
  sentence above true for the one-liner, and makes the saved copy byte-identical to the attested asset.
- **`ci.yml` and `release.yml` pin `pipeline.yml` of `vadyaravadim/latency-toolbox-ci` to the same full
  commit SHA, with its version tag as a comment.** There the release job `needs:` the lint, ASCII and Pester
  jobs of the same run, on the same commit: the push-triggered `ci` runs on `main` do not block a release,
  and a PSGallery version cannot be re-published. A pipeline change reaches this repo only when the pin
  moves: Dependabot proposes the bump monthly, a hand bump changes both lines together (lint fails while
  they differ), and reverting the whole bump - including a `PSScriptAnalyzerSettings.psd1` copy it brought -
  undoes it.
- **The provenance is signed by `pipeline.yml` of `vadyaravadim/latency-toolbox-ci`, not by this repo.**
  `gh attestation verify` needs
  `--signer-workflow vadyaravadim/latency-toolbox-ci/.github/workflows/pipeline.yml` (SECURITY.md); 1.0.1 to
  1.1.0 were signed by this repo's own `release.yml`, 1.0.0 carries no provenance. Never rename or
  delete `latency-toolbox-ci`: GitHub does not redirect a renamed reusable workflow, so every caller breaks.
- **`NUGET_API_KEY` is a secret of the `release` environment, which only `main` can use; the repository has no
  secret of that name.** `release.yml` passes it by name and the shared pipeline's release job runs in that
  environment, so no workflow on another branch can read the key. Rotate it with `gh secret set NUGET_API_KEY
  --env release`. After a pin bump, a dispatch on `main` stops at "Check the version is not released yet"
  while the newest CHANGELOG section is already released - that is the probe.
- **`v*` tags cannot be moved or deleted (tag ruleset) and releases are immutable (repo setting).** A broken
  release is fixed by releasing a new patch version (a new CHANGELOG section), never by re-tagging. The
  ruleset leaves tag creation open on purpose: the release creates the tag with `GITHUB_TOKEN`.
- **Never push a `v*` tag by hand.** It starts no release and cannot be deleted; unless it sits on the exact
  commit the release then runs on, the release stops before publishing and that version is burned.
- **Finish a failed release with "Re-run failed jobs" on that run, not a new run.** The re-run builds the
  same commit with the same pinned pipeline: the Gallery step (`.github/Publish-GalleryScript.ps1` of
  `vadyaravadim/latency-toolbox-ci`) skips a version already there with identical bytes and fails on
  different bytes. A run cancelled during the GitHub Release step can leave a draft - delete it before
  re-running. Release the next version instead only when that run is older than 30 days and can no longer
  be re-run. A failure inside the pipeline itself needs a fixed `latency-toolbox-ci` version, a bump here and
  a new run.

**Before releasing, move the `## [Unreleased]` bullets in `CHANGELOG.md` into a `## [X.Y.Z] - YYYY-MM-DD`
section and add its `[X.Y.Z]: .../compare/vPREV...vX.Y.Z` link at the bottom.** That section is the version.
The release job copies exactly that section into the release body and **fails before anything is tagged or
published when it is empty or its compare link is missing**; a newest section that is already released, or
lower than a released version, fails the same way. This is a gate on purpose, not a fallback: notes are
hand-written because GitHub's `--generate-notes` lists merged PRs, and this repo lands nearly everything as
direct commits to `main`, so it published releases whose whole body was a compare link.

Write the entries for someone who runs the tool, not for someone reading the diff: what changed on their
machine and why it matters. A fix says what was broken and what it cost them.

Do NOT bump `.VERSION` in the `.ps1` by hand - it is a placeholder the workflow overwrites, and a
hand-edited value that disagrees with the tag would only mislead whoever reads the committed file.
**The placeholder is `0.0.0` and must stay exactly that**: the banner reads its own `.VERSION` line and
prints `dev build` for `0.0.0`, the stamped tag otherwise. It used to be `1.0.0`, which is also a real tag,
so a clone of `main` was indistinguishable from the v1.0.0 release.

## README claims

**The README claims only what a published measurement shows** (the companion article, `bench/results`).
An effect nobody measured, on frame times, DPC latency, stutter or input lag, is attributed to the guides
that recommend the tweak or marked as not measured, never stated as fact, and the star ask names no
effect. Frame time and ISR/DPC time are not input lag. The method lives in rigpolice's
`.claude/rules/bench-methodology.md`, section "Conclusions".

## The RigPolice pages that mirror this script

- **The hub card.** `src/lib/latency-toolbox.ts` in the rigpolice repo holds this script's card on
  https://rigpolice.com/system/latency-toolbox/: what it does, what was measured with it, and whether it
  writes an undo file. A release that changes any of those updates the card in the same pass; nothing
  there reads this repo, so the card drifts silently otherwise.
