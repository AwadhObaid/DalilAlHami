[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$LogPrefix
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
    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationId = "20260807133000"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logRoot = Join-Path $root `
        "build_logs\phase10a_supabase_verify_$timestamp"
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

    Write-Host ""
    Write-Host "==> Verifying Phase 10A Supabase migration" `
        -ForegroundColor Cyan
    $result = Invoke-CapturedCommand `
        -Arguments @(
            "--yes", "supabase@latest", "migration", "list", "--linked"
        ) `
        -WorkingDirectory $root `
        -LogPrefix (Join-Path $logRoot "migration_list")

    $output = [string]$result.Output
    $rows = @(
        $output -split "`r?`n" |
            Where-Object { $_ -match [regex]::Escape($migrationId) }
    )
    $confirmed = $rows |
        Where-Object {
            [regex]::Matches($_, [regex]::Escape($migrationId)).Count -ge 2
        } |
        Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($confirmed)) {
        throw (
            "Migration $migrationId was not confirmed on the same " +
            "LOCAL/REMOTE row. Log: $($result.LogPath)"
        )
    }

    Write-Host ("[ OK ] Migration row: " + $confirmed.Trim()) `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
