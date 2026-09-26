<#
.SYNOPSIS
    vencord-setup.ps1 - auto-detects Discord installs and installs/repairs Vencord on them.

.DESCRIPTION
    The one owned delta of the Installer2 fork. Detects existing Discord installs
    (stable / PTB / Canary / Development) under %LOCALAPPDATA%, then downloads the
    released VencordInstallerCli.exe once and drives it with its own flags
    (--install / --repair / --install-openasar / --location / --branch).
    Patching is NOT reimplemented here; the Go CLI is the engine, this script is the driver.

    Admin rights are NOT required (everything happens under %LOCALAPPDATA%).
    Requires Windows PowerShell 5.1 or newer (works on pwsh too).

.USAGE - exact tested one-liner (runs with zero parameters: auto-detect, install/repair Vencord, no OpenAsar):
    iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/nathwn12/Installer2/feat/vencord-main/vencord-setup.ps1'))

.USAGE - parameterized form:
    & ([scriptblock]::Create((iwr -UseBasicParsing 'https://raw.githubusercontent.com/nathwn12/Installer2/feat/vencord-main/vencord-setup.ps1').Content)) -DryRun -IncludeOpenAsar

.PARAMETERS
    -DryRun           Print the plan (installs, patched state, exact CLI commands) and touch nothing.
    -IncludeOpenAsar  Also install OpenAsar on each detected install (default OFF).
    -ExcludeOpenAsar  Explicit no-OpenAsar; identical to the default, exists for explicitness.
    -Branch <b>       Narrow targeting to one branch: stable | ptb | canary | development (alias: dev).
    -Location <path>  Narrow targeting to one Discord install base directory (e.g. %LOCALAPPDATA%\Discord).

.NOTES
    Exit codes: 0 success (and dry-run, even when nothing is found) - 1 install failure - 2 usage/detection error.
    If Discord is running the script closes it automatically (graceful close first, then force-kill), so the patcher never hits errno 32.
#>
param(
    [switch]$DryRun,
    [switch]$IncludeOpenAsar,
    [switch]$ExcludeOpenAsar,
    [string]$Branch = '',
    [string]$Location = ''
)

function Invoke-VencordSetup {
    param(
        [switch]$DryRun,
        [switch]$IncludeOpenAsar,
        [switch]$ExcludeOpenAsar,
        [string]$Branch = '',
        [string]$Location = ''
    )

    $ErrorActionPreference = 'Stop'

    $cliUrl = 'https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe'
    $cliPath = Join-Path ([System.IO.Path]::GetTempPath()) 'VencordInstallerCli.exe'

    # branch display name -> folder name under %LOCALAPPDATA% (mirrors find_discord_windows.go windowsNames)
    $branchFolders = @{
        stable      = 'Discord'
        ptb         = 'DiscordPTB'
        canary      = 'DiscordCanary'
        development = 'DiscordDevelopment'
    }
    $validBranches = @('stable', 'ptb', 'canary', 'development', 'dev')

    function Format-CliCommand([string]$ExePath, [string[]]$ExeArgs) {
        $parts = @('"' + $ExePath + '"')
        foreach ($a in $ExeArgs) {
            if ($a -match '\s') { $parts += '"' + $a + '"' } else { $parts += $a }
        }
        return ($parts -join ' ')
    }

    # Mirrors ParseDiscord in find_discord_windows.go: among app-* dirs, pick the
    # highest (same ordinal string ordering the Go code uses), require resources\app.asar,
    # patched = resources\_app.asar exists.
    function Get-DiscordInstall([string]$BasePath, [string]$BranchName) {
        if (-not (Test-Path -LiteralPath $BasePath -PathType Container)) { return $null }
        $bestName = $null
        $bestDir = $null
        foreach ($d in (Get-ChildItem -LiteralPath $BasePath -Directory -Filter 'app-*')) {
            $resources = Join-Path $d.FullName 'resources'
            if (-not (Test-Path -LiteralPath (Join-Path $resources 'app.asar') -PathType Leaf)) { continue }
            if ($null -eq $bestName -or [string]::CompareOrdinal($d.FullName, $bestName) -gt 0) {
                $bestName = $d.FullName
                $bestDir = $d
            }
        }
        if ($null -eq $bestDir) { return $null }
        $patched = Test-Path -LiteralPath (Join-Path (Join-Path $bestDir.FullName 'resources') '_app.asar') -PathType Leaf
        return [pscustomobject]@{
            Branch  = $BranchName
            Path    = $BasePath
            AppDir  = $bestDir.FullName
            Patched = $patched
        }
    }

    function Invoke-Cli([string]$ExePath, [string[]]$ExeArgs) {
        # 'Continue' here: native stderr merged via 2>&1 must not become a terminating
        # error under the outer 'Stop' preference; lines are surfaced as text below.
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $lines = New-Object System.Collections.Generic.List[string]
        & $ExePath @ExeArgs 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) { $line = $_.ToString() } else { $line = [string]$_ }
            Write-Host ('  ' + $line)
            [void]$lines.Add($line)
        }
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        return [pscustomobject]@{ ExitCode = $code; Output = $lines }
    }

    try {
        # --- validate environment / parameters -----------------------------------
        if ($env:OS -ne 'Windows_NT') {
            Write-Host 'ERROR: This script supports Windows only.'
            exit 2
        }
        if ($IncludeOpenAsar -and $ExcludeOpenAsar) {
            Write-Host 'ERROR: -IncludeOpenAsar and -ExcludeOpenAsar are mutually exclusive.'
            exit 2
        }
        if ($Branch -and $Location) {
            Write-Host 'ERROR: -Branch and -Location are mutually exclusive.'
            exit 2
        }
        $branchNorm = ''
        if ($Branch) {
            $branchNorm = $Branch.ToLowerInvariant()
            if ($validBranches -notcontains $branchNorm) {
                Write-Host ("ERROR: -Branch must be one of: stable | ptb | canary | development (got '{0}')" -f $Branch)
                exit 2
            }
            if ($branchNorm -eq 'dev') { $branchNorm = 'development' }
        }
        # -ExcludeOpenAsar just restates the default (OpenAsar off unless -IncludeOpenAsar).
        $wantOpenAsar = [bool]$IncludeOpenAsar

        Write-Host 'vencord-setup.ps1 - Vencord Installer driver'
        Write-Host ''
        if ($DryRun) {
            Write-Host 'Mode: DRY RUN (plan only - nothing will be downloaded, executed, or modified)'
            Write-Host ''
        }

        # --- detect installs ------------------------------------------------------
        $baseDir = $env:LOCALAPPDATA
        if (-not $baseDir) {
            Write-Host 'ERROR: %LOCALAPPDATA% is empty - cannot detect Discord installs.'
            exit 2
        }

        $targets = @()
        if ($Location) {
            if (-not (Test-Path -LiteralPath $Location -PathType Container)) {
                Write-Host ("ERROR: -Location '{0}' does not exist." -f $Location)
                exit 2
            }
            $inst = Get-DiscordInstall -BasePath $Location -BranchName 'custom'
            if ($null -eq $inst) {
                Write-Host ("ERROR: '{0}' is not a valid Discord install (no app-* dir containing resources\app.asar)." -f $Location)
                exit 2
            }
            $targets += $inst
        }
        else {
            $scanList = @()
            if ($branchNorm) { $scanList = @($branchNorm) } else { $scanList = @('stable', 'ptb', 'canary', 'development') }
            foreach ($b in $scanList) {
                $dir = Join-Path $baseDir $branchFolders[$b]
                if (Test-Path -LiteralPath $dir -PathType Container) {
                    $inst = Get-DiscordInstall -BasePath $dir -BranchName $b
                    if ($null -ne $inst) { $targets += $inst }
                }
            }
        }

        if ($targets.Count -eq 0) {
            Write-Host ("No Discord installs found under {0}." -f $baseDir)
            if ($DryRun) {
                Write-Host 'Nothing to do.'
                return   # dry-run with nothing found: exit 0
            }
            Write-Host 'ERROR: none found. Install Discord first, then re-run this script.'
            exit 2
        }

        Write-Host ("Detected {0} Discord install(s):" -f $targets.Count)
        $i = 0
        foreach ($t in $targets) {
            $i++
            $patchedTxt = 'N'
            if ($t.Patched) { $patchedTxt = 'Y' }
            Write-Host ("  [{0}] branch={1} patched={2} path={3}" -f $i, $t.Branch, $patchedTxt, $t.Path)
        }
        Write-Host ''

        # --- Discord running check -------------------------------------------------
        $procs = @(Get-Process -Name 'Discord*' -ErrorAction SilentlyContinue)
        if ($procs.Count -gt 0) {
            $names = (@($procs | Select-Object -ExpandProperty ProcessName -Unique) -join ', ')
            if ($DryRun) {
                Write-Host ("Discord running check: RUNNING ({0}) - the script will close it automatically before patching (graceful close, then force-kill)" -f $names)
            }
            else {
                # Auto-close: graceful first (CloseMainWindow), then force-kill leftovers.
                Write-Host ("Closing Discord ({0}) to avoid file locks (errno 32)..." -f $names)
                foreach ($p in $procs) { [void]$p.CloseMainWindow() }
                Start-Sleep -Seconds 3
                $left = @(Get-Process -Name 'Discord*' -ErrorAction SilentlyContinue)
                if ($left.Count -gt 0) {
                    foreach ($p in $left) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
                    Start-Sleep -Seconds 2
                }
                $still = @(Get-Process -Name 'Discord*' -ErrorAction SilentlyContinue)
                if ($still.Count -gt 0) {
                    Write-Host 'WARNING: could not close all Discord processes - the patcher may fail with errno 32.'
                }
                else {
                    Write-Host 'Discord closed.'
                }
            }
        }
        else {
            Write-Host 'Discord running check: not running'
        }
        Write-Host ''

        # --- per-install CLI arguments ---------------------------------------------
        # Engine quirk (cli.go isValidBranch): --branch accepts only stable|ptb|canary|auto.
        # 'development' is therefore targeted via --location instead of --branch.
        $cliActions = @{}
        foreach ($t in $targets) {
            $action = @('--install')
            if ($t.Patched) { $action = @('--repair') }
            if ($branchNorm -and $branchNorm -ne 'development') {
                $action += @('--branch', $branchNorm)
            }
            else {
                $action += @('--location', $t.Path)
            }
            $cliActions[$t.Path] = $action
        }

        # --- dry run: print the exact plan and stop ---------------------------------
        if ($DryRun) {
            Write-Host 'Plan:'
            $i = 0
            foreach ($t in $targets) {
                $i++
                Write-Host ("  would run: {0}" -f (Format-CliCommand $cliPath $cliActions[$t.Path]))
                if ($wantOpenAsar) {
                    $oaArgs = @('--install-openasar')
                    if ($branchNorm -and $branchNorm -ne 'development') {
                        $oaArgs += @('--branch', $branchNorm)
                    }
                    else {
                        $oaArgs += @('--location', $t.Path)
                    }
                    Write-Host ("  would run: {0}" -f (Format-CliCommand $cliPath $oaArgs))
                }
            }
            Write-Host ''
            Write-Host 'Dry run complete - nothing was downloaded, executed, or modified.'
            return   # exit 0
        }

        # --- download the CLI once ---------------------------------------------------
        Write-Host ("Downloading VencordInstallerCli.exe to {0} ..." -f $cliPath)
        $tls = [System.Net.ServicePointManager]::SecurityProtocol
        [System.Net.ServicePointManager]::SecurityProtocol = ($tls -bor [System.Net.SecurityProtocolType]::Tls12)
        Invoke-WebRequest -Uri $cliUrl -OutFile $cliPath -UseBasicParsing
        if (-not (Test-Path -LiteralPath $cliPath -PathType Leaf)) {
            throw 'Download failed: the installer executable was not written to the temp folder.'
        }
        if ((Get-Item -LiteralPath $cliPath).Length -le 0) {
            throw 'Download failed: the installer executable is empty.'
        }
        $fs = [System.IO.File]::OpenRead($cliPath)
        $b0 = $fs.ReadByte()
        $b1 = $fs.ReadByte()
        $fs.Close()
        if ($b0 -ne 0x4D -or $b1 -ne 0x5A) {
            throw 'Download failed: the downloaded file is not a valid Windows executable.'
        }
        Unblock-File -LiteralPath $cliPath -ErrorAction SilentlyContinue
        Write-Host 'Download complete.'
        Write-Host ''

        # --- execute per install -------------------------------------------------------
        $okCount = 0
        $failures = @()
        $i = 0
        foreach ($t in $targets) {
            $i++
            Write-Host ("[{0}/{1}] {2} ({3})" -f $i, $targets.Count, $t.Branch, $t.Path)

            $verb = 'install'
            if ($t.Patched) { $verb = 'repair' }
            Write-Host ("  Running: {0}" -f (Format-CliCommand $cliPath $cliActions[$t.Path]))
            $r = Invoke-Cli -ExePath $cliPath -ExeArgs $cliActions[$t.Path]
            if ($r.ExitCode -eq 0) {
                $okCount++
            }
            else {
                Write-Host ("  FAILED: VencordInstallerCli.exe {0} exited with code {1}." -f $verb, $r.ExitCode)
                $failures += ("{0} ({1})" -f $t.Branch, $t.Path)
            }

            if ($wantOpenAsar) {
                $oaArgs = @('--install-openasar')
                if ($branchNorm -and $branchNorm -ne 'development') {
                    $oaArgs += @('--branch', $branchNorm)
                }
                else {
                    $oaArgs += @('--location', $t.Path)
                }
                Write-Host ("  Running: {0}" -f (Format-CliCommand $cliPath $oaArgs))
                $roa = Invoke-Cli -ExePath $cliPath -ExeArgs $oaArgs
                $alreadyInstalled = $false
                if ($roa.ExitCode -eq 1) {
                    foreach ($ln in $roa.Output) {
                        if ($ln -match 'OpenAsar already installed') { $alreadyInstalled = $true }
                    }
                }
                if ($roa.ExitCode -eq 0) {
                    Write-Host '  OpenAsar installed.'
                }
                elseif ($alreadyInstalled) {
                    Write-Host '  OpenAsar is already installed on this install - nothing to do.'
                }
                else {
                    Write-Host ("  FAILED: VencordInstallerCli.exe --install-openasar exited with code {0}." -f $roa.ExitCode)
                    $failures += ("{0} ({1}) [openasar]" -f $t.Branch, $t.Path)
                }
            }
            Write-Host ''
        }

        # --- summary ----------------------------------------------------------------------
        Write-Host ("Done: {0} install(s) processed successfully, {1} failed." -f $okCount, $failures.Count)
        if ($failures.Count -gt 0) {
            foreach ($f in $failures) { Write-Host ("  failed: {0}" -f $f) }
            Write-Host 'Close Discord if it is running, then re-run this script to retry.'
            exit 1
        }
        Write-Host 'Vencord is set up. Restart Discord to load it.'
    }
    catch {
        Write-Host ("ERROR: {0}" -f $_.Exception.Message)
        exit 1
    }
}

# Auto-run for the iex one-liner (no arguments) AND for scriptblock invocation with
# arguments. Set VENCORD_SETUP_IMPORTED=1 to dot-import the function without running.
if (-not $env:VENCORD_SETUP_IMPORTED) {
    Invoke-VencordSetup @PSBoundParameters
}
