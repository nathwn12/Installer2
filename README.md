# Vencord Setup

One line. Your Discord is detected automatically — Vencord gets installed or repaired. Done.

> Windows + PowerShell 5.1+ · no admin needed · you don't even need to close Discord — the script closes it for you.

## Install (Vencord only)

```powershell
iex (irm 'https://raw.githubusercontent.com/nathwn12/Installer2/feat/vencord-main/vencord-setup.ps1')
```

## Install (Vencord + OpenAsar)

```powershell
& ([scriptblock]::Create((irm 'https://raw.githubusercontent.com/nathwn12/Installer2/feat/vencord-main/vencord-setup.ps1'))) -IncludeOpenAsar
```

Optional preview without touching anything — add `-DryRun` to the second form.

## What you get

- ✅ **One line, zero clicks** — paste, Enter, done. That's the whole install.
- ✅ **Auto-detect** — finds your Discord (stable / PTB / Canary / Development) under `%LOCALAPPDATA%` and points itself at it.
- ✅ **Auto install *or* repair** — already patched? It repairs. Fresh? It installs. No menus, no prompts.
- ✅ **Discord open? Doesn't matter** — the script closes it for you (gracefully; force-kill only as a fallback).
- ✅ **Always current** — pulls the official Vencord build at run time, so it never goes stale.
- ✅ **OpenAsar opt-in** — off by default; one flag to include, one to exclude.
- ✅ **Safe to re-run** — idempotent: run it again anytime to repair or refresh.

Powered by the official **Vencord Installer** engine — this script just drives it so you don't have to think.

---

## Credits & license — all credit to the original owners

**This fork takes no credit and makes no money. It exists purely for personal use.**

- **Vencord** — by **Vendicated** and contributors: <https://github.com/Vendicated/Vencord>
- **Vencord Installer** — the engine this script drives, by **Vendicated** and contributors: <https://github.com/Vencord/Installer>
- Vencord, its installer, and this fork are licensed under the **GNU GPL v3** — see [LICENSE](LICENSE).

All rights, credit, and ownership belong to the original authors. This repository is a personal-use fork: no affiliation, no endorsement, no monetary gain, nothing sold or charged. Everything of value here is theirs — the only addition is one convenience script.
