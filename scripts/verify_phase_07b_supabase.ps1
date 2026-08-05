[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationId = "20260805234500"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logRoot = Join-Path $resolvedRoot `
        "build_logs\phase07b_verify_$timestamp"
    $stdoutPath = Join-Path $logRoot "migration_list.stdout.log"
    $stderrPath = Join-Path $logRoot "migration_list.stderr.log"
    $combinedPath = Join-Path $logRoot "migration_list.combined.log"
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

    $process = Start-Process `
        -FilePath "npx.cmd" `
        -ArgumentList @(
            "--yes", "supabase@latest", "migration", "list", "--linked"
        ) `
        -WorkingDirectory $resolvedRoot `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath

    @(
        "===== STDOUT ====="
        (Get-Content -LiteralPath $stdoutPath -Raw `
            -ErrorAction SilentlyContinue)
        ""
        "===== STDERR / PROGRESS ====="
        (Get-Content -LiteralPath $stderrPath -Raw `
            -ErrorAction SilentlyContinue)
    ) | Set-Content -LiteralPath $combinedPath -Encoding UTF8

    Get-Content -LiteralPath $combinedPath

    if ($process.ExitCode -ne 0) {
        throw (
            "Supabase migration list failed with exit code " +
            "$($process.ExitCode)."
        )
    }

    $combined = Get-Content -LiteralPath $combinedPath -Raw
    $matches = [regex]::Matches($combined, $migrationId)
    if ($matches.Count -lt 2) {
        throw (
            "Migration $migrationId was not confirmed in LOCAL and REMOTE."
        )
    }

    $markerPath = Join-Path $resolvedRoot `
        "PHASE_07B_SUPABASE_VERIFIED.txt"
    @(
        "Dalil Al Hami - Phase 07B Supabase verified"
        "Migration: $migrationId"
        "Verified at: $(Get-Date -Format o)"
        "Log: $combinedPath"
    ) | Set-Content -LiteralPath $markerPath -Encoding UTF8

    Write-Host (
        "[ OK ] Migration $migrationId exists locally and remotely."
    ) -ForegroundColor Green
    Write-Host "[ OK ] Marker: $markerPath" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
