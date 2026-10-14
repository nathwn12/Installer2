# Live launch of Discord Canary after setup (2026-10-14)

## Apply

- Command: `pwsh -NoProfile -File .\vencord-setup.ps1 -Branch canary` (repo root, `feat/vencord-main` @ `f9ffec9`).
- DiscordCanary was RUNNING (5 processes) at run start: the script auto-closed it (graceful `CloseMainWindow`, then force-kill), repaired via the released CLI (`--repair --branch canary`), verified the patch on disk, then launched it.
- Engine: "already patched. Unpatching first..." → "Successfully patched" → script verify gate `Verified: patch is on disk.` → engine exit 0, script exit 0.

## Verify

- Launch line (verbatim, `%LOCALAPPDATA%` form): `Launched canary: "%LOCALAPPDATA%\DiscordCanary\Update.exe" --processStart DiscordCanary.exe`
- After the run: 4 `DiscordCanary` processes with `StartTime` 16:01:34.582 – 16:01:35.533, all later than the run start 16:01:27.076; PID 18356 had `MainWindowTitle` = `Discord` (window up, Vencord loading).
- Dry run: `-DryRun` printed `would launch: "%LOCALAPPDATA%\DiscordCanary\Update.exe" --processStart DiscordCanary.exe  (from %LOCALAPPDATA%\DiscordCanary)` and launched nothing — the PID set was identical before and after (4712, 13020, 23044, 25100, 25864).
- `-DryRun -NoLaunch` printed `Launch skipped (-NoLaunch)` with no `would launch:` line.

## Notes

- Branch-agnostic by construction: the exe name is read from the `app-*` dir (`Discord*.exe` preferred, `updater_launcher.exe` never, branch folder name as last-resort fallback) and the launch goes through the install's own `Update.exe`, so stable / PTB / canary / development need no per-branch table.
- Only canary has a valid install on this machine (stable: `%LOCALAPPDATA%\Discord` has no `app-*` dir; PTB absent; development has `Update.exe` but no `app-*` dir), so live proof of the resolution path covers canary only plus the dry-run plan for others.
- POLICY: launch happens only on the all-success path (the `exit 1` failure branch returns first), only when the patch verified on disk, and once per target; `-NoLaunch` skips it. A launch failure cannot change the exit code.
