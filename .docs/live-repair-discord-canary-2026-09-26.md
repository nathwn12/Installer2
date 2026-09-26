# Live repair of Discord Canary via vencord-setup.ps1 (2026-09-26)

## Apply

- Command: `& ([scriptblock]::Create((Get-Content -Raw .\vencord-setup.ps1)))` (repo root, `feat/vencord-main` @ `59be263`), run under `powershell.exe -NoProfile`.
- Script detected canary (`C:\Users\nathan\AppData\Local\DiscordCanary`), found it already patched → engine `--repair`. Discord was closed at run time (auto-close feature added same session: graceful `CloseMainWindow`, then force-kill — not exercised here because Discord was already closed).
- Engine downloaded latest Vencord build, unpatched the existing patch, re-patched. Engine exit 0, script exit 0.

## Verify

- `%LOCALAPPDATA%\DiscordCanary\app-1.0.1192\resources\`: `_app.asar` (41,443 B — original), `app.asar` (220 B — stub), `app.asar.backup` (3.6 MB, written by upstream CLI).
- Stub `app.asar` decodes to `require("C:\Users\nathan\AppData\Roaming\Vencord\dist\patcher.js")` + package.json.
- Payload present at `%APPDATA%\Vencord\dist\`: patcher.js, preload.js, renderer.js (+maps, LEGAL files).

## Revert

- Unpatch: run the upstream CLI with `--uninstall` (or the GUI "Uninstall Vencord"): it renames `_app.asar` back to `app.asar` and removes the stub. Original files are preserved as `_app.asar` / `app.asar.backup` — nothing on the Discord side is destroyed by the patch.
- OpenAsar was NOT installed in this run (default OFF).

## Notes

- This is the first real (non-dry-run) execution of the script; the driver's repair path is now exercised.
