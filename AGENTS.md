# AGENTS.md

## What this fork is — read this first

Fork of `Vencord/Installer` (upstream), hosted at `nathwn12/Installer2`. Work happens on branch `feat/vencord-main` (create from `main` if it doesn't exist yet). This fork is a **thin proxy**: upstream is the product and does the real work — we add one automation script and nothing else. `main` mirrors upstream; `feat/vencord-main` carries the delta on top of it.

**The only owned delta is one PowerShell script** (root-level `.ps1`). Everything else must stay merge-clean with upstream:

- Auto-detects existing Discord install(s) (`%LOCALAPPDATA%\Discord`, `DiscordPTB`, `DiscordCanary`, `DiscordDevelopment`).
- Auto-installs/repairs Vencord on the detected install — one operation, no menus. If already patched (check: `_app.asar` next to `app.asar` in `app-*/resources`), repair; otherwise install.
- OpenAsar is opt-in: include/exclude subcommand or flag. Default OFF.
- `--dry-run`: print the plan (target path, branch, actions) and touch nothing.
- Callable as a one-liner via `iex`. Constraint you must design around: `iex (iwr <url>)` executes text with **no arguments** — the script must auto-run correctly with zero params, and expose its params for `& ([scriptblock]::Create((iwr <url>))) -DryRun -IncludeOpenAsar` style invocation.
- Auto-closes Discord before patching (graceful `CloseMainWindow`, then force-kill leftovers). Dry-run never kills anything.
- Implementation: do **not** reimplement patching in PowerShell. Download the released `VencordInstallerCli.exe` (the existing `install.ps1` shows the pattern) and drive it with its flags (`--install`, `--repair`, `--install-openasar`, `--branch`, `--location`). The Go side is the engine; the script is the driver. errno 32 (sharing violation) means a Discord process is still open.

## Maintenance rules (how we stay sane)

1. **Upstream wins.** Never refactor, restyle, or "improve" upstream Go code. Every changed line outside the script (and this file) must trace to a merge conflict or a script-breaking upstream change.
2. **Sync ritual, always before any work:** add upstream if missing (`git remote add upstream https://github.com/Vencord/Installer`), then `git fetch upstream`, then **merge** `upstream/main` into `feat/vencord-main` (pull/merge flow — never rebase the branch).
3. **Conflict policy:** take upstream's side everywhere except the script, `AGENTS.md`, and `README.md` (owner-approved rewrite — upstream's README does not come back). In Go code, only override upstream if it breaks the script's interface (CLI flags, build output names).
4. After every merge: `go build`, `go build -tags cli`, `go vet -tags cli ./...` — and a `-DryRun` test of the script. That's the whole verify story.

## Verify changes (no tests exist)

No test suite, no linter config, no pre-commit hooks. CI runs only on `v*` tag pushes — it is not a PR check, and the fork doesn't tag (the deliverable is the script, not releases). Verify = the four commands above.

## Script must-know about the engine

- Two UIs, one package: `cli.go` is `//go:build cli`, `gui.go` is `//go:build !cli`. Plain `go build` compiles the **GUI**; the CLI binary needs `-tags cli`. GUI needs CGO 1 (GCC/MinGW on Windows); CLI is CGO-free static. The script depends only on the released CLI exe — this matters for merge verification, not for the script itself.
- CLI flags (the surface the script drives): `--install`, `--repair` (repair/update), `--uninstall`, `--install-openasar`, `--uninstall-openasar`, `--location <path>`, `--branch <stable|ptb|canary|auto>`, `--update-self`, `--debug`. `--location` and `--branch` are mutually exclusive.
- Patch mechanics: rename real `app.asar` → `_app.asar`, write stub `app.asar` requiring external `patcher.js` (downloaded at runtime from GitHub API with vencord.dev fallback). The rename rollback order in `patchAppAsar`/`unpatchAppAsar` is the bricking-prevention — never reorder.
- Runtime env overrides useful for testing: `VENCORD_DEV_INSTALL=1` (skip GitHub fetch), `VENCORD_USER_DATA_DIR`/`DISCORD_USER_DATA_DIR` (data dir), `--debug` flag for verbose logs.
- Upstream release chain (FYI only): `v*` tag → build all platforms → **draft** release → manual publish → winget auto-submits `VencordInstallerCli.exe`. Don't tag casually.

## Standing state

- `feat/vencord-main`: **live** — work happens here, merge `upstream/main` into it on every session start.
- `upstream` remote: added (`https://github.com/Vencord/Installer`); fork base is exactly upstream's head as of 2026-09-26 (`fe6e041`) — future merges start clean.
- The script: **`vencord-setup.ps1`** (repo root) — the fork's one owned delta. One-liner (paramless auto-run; **must stay pure ASCII, no BOM** — a BOM breaks `irm`/`scriptblock` parsing over HTTP):
  `iex (irm 'https://raw.githubusercontent.com/nathwn12/Installer2/feat/vencord-main/vencord-setup.ps1')`
  Parameterized: `& ([scriptblock]::Create((irm '<url>'))) -DryRun -IncludeOpenAsar`. Set `VENCORD_SETUP_IMPORTED=1` to import without auto-run. After pushing script changes, raw.githubusercontent may serve the old blob for ~5 min (edge cache) — don't judge a fresh one-liner by an immediate self-fetch.
- Verify the script with `-DryRun` (2 valid installs on the maintainer machine: none stable — the `Discord` dir has no `app-*` — and canary, already patched; canary is the real target).
