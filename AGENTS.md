# Installer2 — script-only Vencord setup (personal use)

This repo is ONE product: `vencord-setup.ps1`. It auto-detects Discord
installs and drives upstream's official released engine
(`VencordInstallerCli.exe`, downloaded at run time) with its own flags.
Patching is NOT reimplemented here. All credit to Vencord upstream.

## File map

- `vencord-setup.ps1` — the product. The only executable thing here.
- `README.md` — user-facing install docs (owned by quill).
- `LICENSE` — upstream's license, kept with the fork.
- `.github/workflows/script-smoke.yml` — dry-run smoke test on push.

## Editing the script

- Keep it pure ASCII, no BOM. A BOM breaks `irm`/`scriptblock` parsing.
- Verify every change: `pwsh -NoProfile -File vencord-setup.ps1 -DryRun`.
- `raw.githubusercontent` caches ~5 min. Never judge a fresh push by an
  immediate fetch — retry before concluding anything is broken.

## Branches

- `main` = the product. This is the only live branch.
- `feat/vencord-main` = frozen history. Kept so old raw URLs keep
  resolving; never merge into it, never build on it.
- Fork-era session notes live in `.docs/` on frozen `feat/vencord-main`.

## Removed (do NOT re-add)

- The Go engine mirror + `sync-upstream` machinery + release/winget
  workflows. Nothing consumed them: the script downloads upstream's
  released engine at run time, the fork has zero releases, and the
  6-hourly sync served no consumer. That is why they are gone.
- No releases, no tags. The deliverable is the script, not releases.
