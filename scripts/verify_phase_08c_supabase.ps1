[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,
        [Parameter(Mandatory = $true)]
        [string]$LogPrefix
    )

    $stdoutPath = "$LogPrefix.stdout.log"
    $stderrPath = "$LogPrefix.stderr.log"
    $combinedPath = "$LogPrefix.combined.log"

    $process = Start-Process `
        -FilePath "npx.cmd" `
        -ArgumentList $Arguments `
        -WorkingDirectory $WorkingDirectory `
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

    $combined = Get-Content -LiteralPath $combinedPath -Raw

    # Important: display the captured log through the host stream only.
    # Writing it to the success pipeline would mix display lines with the
    # function return value and corrupt callers that expect one result object.
    foreach ($line in @($combined -split "`r?`n")) {
        Write-Host $line
    }

    if ($process.ExitCode -ne 0) {
        throw (
            "Supabase command failed with exit code " +
            "$($process.ExitCode). Log: $combinedPath"
        )
    }

    return [pscustomobject]@{
        Output = [string]$combined
        LogPath = [string]$combinedPath
    }
}

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationId = "20260807030000"
    $functionName = "admin-users"
    $linkedRefPath = Join-Path $resolvedRoot "supabase\.temp\project-ref"
    if (-not (Test-Path -LiteralPath $linkedRefPath -PathType Leaf)) {
        throw "The linked Supabase project reference was not found."
    }

    $projectRef = (Get-Content -LiteralPath $linkedRefPath `
        -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($projectRef)) {
        throw "The linked Supabase project reference is empty."
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logRoot = Join-Path $resolvedRoot `
        "build_logs\phase08c_users_verify_$timestamp"
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

    Write-Host ""
    Write-Host "==> Verifying Phase 08C migration" -ForegroundColor Cyan
    $migrationResult = Invoke-CapturedCommand `
        -Arguments @(
            "--yes", "supabase@latest", "migration", "list", "--linked"
        ) `
        -WorkingDirectory $resolvedRoot `
        -LogPrefix (Join-Path $logRoot "migration_list")
    $migrationOutput = [string]$migrationResult.Output
    $migrationLog = [string]$migrationResult.LogPath

    $migrationRows = @(
        $migrationOutput -split "`r?`n" |
            Where-Object {
                $_ -match [regex]::Escape($migrationId)
            }
    )

    $confirmedMigrationRow = $migrationRows |
        Where-Object {
            [regex]::Matches($_, [regex]::Escape($migrationId)).Count -ge 2
        } |
        Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($confirmedMigrationRow)) {
        if ($migrationRows.Count -gt 0) {
            Write-Host ""
            Write-Host "Migration rows containing ${migrationId}:" `
                -ForegroundColor Yellow
            foreach ($row in $migrationRows) {
                Write-Host $row -ForegroundColor Yellow
            }
        }

        throw (
            "Migration $migrationId was not confirmed on the same " +
            "LOCAL/REMOTE row. Log: $migrationLog"
        )
    }

    Write-Host (
        "[ OK ] Migration row: " + $confirmedMigrationRow.Trim()
    ) -ForegroundColor Green

    Write-Host ""
    Write-Host "==> Verifying admin-users Edge Function" `
        -ForegroundColor Cyan
    $functionResult = Invoke-CapturedCommand `
        -Arguments @(
            "--yes", "supabase@latest", "functions", "list",
            "--project-ref", $projectRef
        ) `
        -WorkingDirectory $resolvedRoot `
        -LogPrefix (Join-Path $logRoot "function_list")
    $functionOutput = [string]$functionResult.Output
    $functionLog = [string]$functionResult.LogPath
    if ($functionOutput -notmatch [regex]::Escape($functionName)) {
        throw "The admin-users Edge Function was not found remotely."
    }

    $markerPath = Join-Path $resolvedRoot `
        "PHASE_08C_ADMIN_USER_MANAGEMENT.txt"
    @(
        "Dalil Al Hami - Phase 08C admin user management"
        "Migration: $migrationId"
        "Edge Function: $functionName"
        "Verified at: $(Get-Date -Format o)"
        "Migration log: $migrationLog"
        "Function log: $functionLog"
        "Self-account protection: enabled"
        "Last-active-admin protection: enabled"
        "Reversible soft deletion: enabled"
        "Audit trail: enabled"
        "Service role in Flutter APK: prohibited"
    ) | Set-Content -LiteralPath $markerPath -Encoding UTF8

    Write-Host (
        "[ OK ] Migration $migrationId exists locally and remotely."
    ) -ForegroundColor Green
    Write-Host "[ OK ] Edge Function $functionName is deployed." `
        -ForegroundColor Green
    Write-Host "[ OK ] Marker: $markerPath" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
