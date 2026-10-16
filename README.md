<p align="center">
  <img src="assets/icon.svg" width="120" height="120" alt="Installer2 icon" />
</p>
<h1 align="center">Installer2</h1>
<p align="center"><strong>One line. Your Discord is detected automatically — Vencord gets installed or repaired. Done.</strong></p>
<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/nathwn12/Installer2" alt="License" /></a>
  <img src="https://img.shields.io/github/languages/top/nathwn12/Installer2" alt="Language" />
  <img src="https://img.shields.io/badge/platform-windows--linux-2b3137" alt="Platform" />
</p>

## Project name and description

Installer2 is a personal-use fork of `Vencord/Installer` that adds exactly one thing: `vencord-setup.ps1`, a zero-click PowerShell driver that finds your Discord install and installs or repairs Vencord on it. It is for Windows users who want Vencord without menus, prompts, or a manual GUI run. Everything that does the real patching is still the upstream Vencord installer engine.

## Technology stack

Go 1.20 engine (module `vencordinstaller`): the GUI build needs CGO with GCC/MinGW on Windows, the CLI build (`-tags cli`) is CGO-free and static. One PowerShell 5.1+ script, pure ASCII with no BOM so it survives `irm`/`scriptblock` execution over HTTP. The engine builds for Windows, Linux, and macOS; the script targets Windows Discord installs (stable, PTB, Canary, Development).

## Architecture

Thin proxy: the script downloads the released `VencordInstallerCli.exe` and drives its flags (`--install`, `--repair`, `--install-openasar`, `--branch`, `--location`) — patching is never reimplemented in PowerShell. The Go side is two UIs in one package: `cli.go` carries `//go:build cli`, `gui.go` carries `//go:build !cli`, so plain `go build` yields the GUI. Patch mechanics rename the real `app.asar` to `_app.asar` and write a stub that loads an external `patcher.js`. After each engine run the script verifies the patch landed on disk (`_app.asar` present, stub `app.asar` under 64KB) and retries transient failures up to twice, re-closing Discord first.

## Getting started

Prerequisites: Windows, PowerShell 5.1 or newer, no admin needed. You do not need to close Discord — the script closes it for you.

```powershell
iex (irm 'https://raw.githubusercontent.com/nathwn12/Installer2/feat/vencord-main/vencord-setup.ps1')
```

Vencord plus opt-in OpenAsar, with a preview that touches nothing:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/nathwn12/Installer2/feat/vencord-main/vencord-setup.ps1'))) -IncludeOpenAsar -DryRun
```

A dry run prints the plan (target path, branch, actions) and kills nothing. On success the script relaunches the Discord install it just set up through that install's own `Update.exe`.

## Project structure

- `vencord-setup.ps1` — the fork's one owned delta: detect, install/repair, verify, relaunch.
- Root `*.go` — upstream installer engine: `cli.go`/`gui.go` (build-tagged UIs), `patcher.go`, `openasar.go`, `github_downloader.go`, `find_discord_*.go`, `self_updater.go`, plus small helpers.
- `install.ps1` — upstream's install pattern the script follows.
- `go.mod` / `go.sum` — Go module `vencordinstaller`, Go 1.20.
- `Makefile` — upstream build targets.
- `buildinfo/` — build-tag stubs selecting the CLI or GUI entrypoint.
- `macos/` — upstream macOS packaging assets (dmg background, icons, app bundle).
- `winres/` — upstream Windows resources (`icon.ico`, `icon.png`, `winres.json`).
- `.docs/` — notes from live verification runs.
- `.github/` — upstream CI plus the fork's 6-hour upstream-sync workflow (lives on `main`).
- `AGENTS.md` — the contributor contract for this fork.
- `LICENSE` — upstream GNU GPL v3 text.
- `README.md` — this file.

## Key features

- One line, zero clicks: paste, Enter, done.
- Auto-detects Discord stable, PTB, Canary, and Development under `%LOCALAPPDATA%`.
- Installs fresh or repairs an existing patch, no menus or prompts.
- Closes Discord gracefully before patching; force-kill only as fallback.
- Pulls the official Vencord build at run time, so it never goes stale.
- OpenAsar support, off by default, one flag to include.
- Idempotent and safe to re-run for repair or refresh.
- `-DryRun` previews the full plan without touching anything.

## Development workflow

Work happens on `feat/vencord-main`; `main` mirrors upstream plus the sync machinery. Sync ritual before any work: `git fetch upstream`, then merge `upstream/main` into `feat/vencord-main` — merge flow, never rebase (a scheduled workflow also merges every 6 hours). Conflict policy: take upstream's side everywhere except the script, `AGENTS.md`, and `README.md`. The fork never tags releases — the deliverable is the script, not binaries.

## Testing

No test suite, no linter config, no pre-commit hooks. Verify a change with these three commands, then a `-DryRun` of the script:

```powershell
go build
go build -tags cli
go vet -tags cli ./...
```

## Contributing

Read [AGENTS.md](AGENTS.md) first. The standing rule is upstream wins: never refactor or restyle upstream Go code — every changed line outside the script must trace to a merge conflict or a script-breaking upstream change.

## License

GPL-3.0-or-later — see [LICENSE](LICENSE).

## Credits

Upstream is [Vencord](https://github.com/Vendicated/Vencord) by Vendicated and contributors, and the patching engine is [Vencord Installer](https://github.com/Vencord/Installer) by the same authors. This fork is not affiliated with or endorsed by them, takes no credit, and makes no money — it exists for personal use, and the only addition is one convenience script.

<!-- nathwn12 house footer: identical in every repo. Do not edit. -->
<p align="center">
  <a href="https://github.com/nathwn12"><img src="assets/signature.svg" width="96" alt="nathwn12" /></a>
</p>
<p align="center">
  <sub>Built by <a href="https://github.com/nathwn12">nathwn12</a> · <a href="https://github.com/nathwn12?tab=repositories">All projects</a></sub>
</p>
