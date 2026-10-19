# Installer2

**Install or repair Vencord on your Discord installs with one line.**

Unofficial, personal-use driver. All credit to the original authors: [Vencord](https://github.com/Vendicated/Vencord) by Vendicated and contributors, and the [Vencord Installer](https://github.com/Vencord/Installer) engine it downloads at run time.

## Install

```powershell
iex (irm 'https://raw.githubusercontent.com/nathwn12/Installer2/main/vencord-setup.ps1')
```

You need Discord already installed on Windows with PowerShell 5.1 or newer. The first run detects your installs, downloads the official engine once, installs or repairs Vencord, then launches Discord.

To include OpenAsar on each install:

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/nathwn12/Installer2/main/vencord-setup.ps1'))) -IncludeOpenAsar
```

To preview the plan without changing anything, add `-DryRun` to the second form.

## Use it

Run the second Install form with the flags you want. Add `-IncludeOpenAsar` to also install OpenAsar, `-Branch` to target one branch only (stable, ptb, canary, or development), `-Location` to target one install folder only, or `-NoLaunch` to skip the automatic launch after success. Add `-DryRun` any time to print the plan without downloading or changing anything.

## What you get

- Automatic detection of your Discord installs across stable, PTB, Canary, and Development.
- Install-or-repair behavior: a fresh install gets Vencord, an already patched install gets repaired.
- Automatic Discord close before patching, so a file lock never blocks the run.
- Always current engine: every run pulls the officially released executable at run time.
- OpenAsar as an opt-in on each install, off unless you ask for it.
- Safe re-runs: run it again any time to repair or refresh.
- Automatic launch of each install you just set up after a successful run.

## Requirements

- Windows.
- PowerShell 5.1 or newer, including current PowerShell.
- Discord already installed.
- Network access to GitHub for the script and the engine download.
- No admin rights needed.

## Links

- Upstream Vencord: https://github.com/Vendicated/Vencord
- Upstream Installer: https://github.com/Vencord/Installer
- Upstream releases, the engine this script downloads at run time: https://github.com/Vencord/Installer/releases
- This repo: https://github.com/nathwn12/Installer2
- License: GPLv3, see [LICENSE](LICENSE)

<!-- nathwn12 house footer: identical in every repo. Do not edit. -->
<p align="center">
  <a href="https://github.com/nathwn12"><img src="assets/signature.svg" width="96" alt="nathwn12" /></a>
</p>
<p align="center">
  <sub>Built by <a href="https://github.com/nathwn12">nathwn12</a> · <a href="https://github.com/nathwn12?tab=repositories">All projects</a></sub>
</p>
