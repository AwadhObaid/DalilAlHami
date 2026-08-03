[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

try {
    Write-Step "Checking Phase 05B-1 Supabase migration"

    $resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationId = "20260803231500"
    $migrationFile = Join-Path $resolvedProjectRoot `
        "supabase\migrations\20260803231500_incremental_directory_sync.sql"

    if (-not (Test-Path -LiteralPath $migrationFile -PathType Leaf)) {
        throw "Phase 05B-1 migration file was not found."
    }

    $npxCommand = Get-Command "npx.cmd" -ErrorAction SilentlyContinue
    if ($null -eq $npxCommand) {
        $npxCommand = Get-Command "npx" -ErrorAction SilentlyContinue
    }
    if ($null -eq $npxCommand) {
        throw "npx was not found in PATH."
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logsRoot = Join-Path $resolvedProjectRoot `
        "build_logs\phase05b1_supabase_verify_$timestamp"
    New-Item -ItemType Directory -Path $logsRoot -Force | Out-Null

    $stdoutPath = Join-Path $logsRoot "migration_list.stdout.log"
    $stderrPath = Join-Path $logsRoot "migration_list.stderr.log"
    $combinedPath = Join-Path $logsRoot "migration_list.combined.log"

    Write-Step "Reading local and remote migration history"

    $process = Start-Process `
        -FilePath $npxCommand.Source `
        -ArgumentList @(
            "--yes",
            "supabase@latest",
            "migration",
            "list",
            "--linked"
        ) `
        -WorkingDirectory $resolvedProjectRoot `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath

    $stdout = ""
    $stderr = ""

    if (Test-Path -LiteralPath $stdoutPath) {
        $stdout = Get-Content -LiteralPath $stdoutPath -Raw
    }
    if (Test-Path -LiteralPath $stderrPath) {
        $stderr = Get-Content -LiteralPath $stderrPath -Raw
    }

    @(
        "===== STDOUT ====="
        $stdout
        ""
        "===== STDERR / PROGRESS ====="
        $stderr
    ) | Set-Content -LiteralPath $combinedPath -Encoding UTF8

    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        Write-Host $stdout
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        Write-Host $stderr -ForegroundColor DarkGray
    }

    if ($process.ExitCode -ne 0) {
        throw (
            "Supabase migration list failed with exit code " +
            $process.ExitCode + ". Log: " + $combinedPath
        )
    }

    $allOutput = $stdout + "`r`n" + $stderr
    $migrationMatches = [regex]::Matches(
        $allOutput,
        [regex]::Escape($migrationId)
    )

    if ($migrationMatches.Count -lt 2) {
        throw (
            "Migration $migrationId was not confirmed in both LOCAL " +
            "and REMOTE columns. Log: $combinedPath"
        )
    }

    $verificationMarker = Join-Path $resolvedProjectRoot `
        "PHASE_05B1_SUPABASE_VERIFIED.txt"

    @(
        "Dalil Al Hami - Phase 05B-1 Supabase verification"
        "Migration: $migrationId"
        "Status: local and remote"
    ) | Set-Content -LiteralPath $verificationMarker -Encoding UTF8

    Write-Ok "Migration $migrationId exists locally and remotely."
    Write-Ok "Docker Desktop is not required for this verification."
    Write-Ok "Verification log: $combinedPath"
    Write-Ok "Marker: $verificationMarker"

    Write-Host ""
    Write-Host "======================================================" `
        -ForegroundColor DarkCyan
    Write-Host "Phase 05B-1 Supabase verification succeeded." `
        -ForegroundColor Green
    Write-Host "The incremental synchronization phase can be tested." `
        -ForegroundColor White
    Write-Host "======================================================" `
        -ForegroundColor DarkCyan
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
