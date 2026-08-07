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
    $migrationId = "20260807193000"
    $functionName = "admin-notifications"
    $secretName = "FIREBASE_SERVICE_ACCOUNT_JSON"
    $linkedRefPath = Join-Path $root "supabase\.temp\project-ref"

    if (-not (Test-Path -LiteralPath $linkedRefPath -PathType Leaf)) {
        throw "The linked Supabase project reference was not found."
    }
    $projectRef = (Get-Content -LiteralPath $linkedRefPath `
        -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($projectRef)) {
        throw "The linked Supabase project reference is empty."
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logRoot = Join-Path $root `
        "build_logs\phase10b_notifications_verify_$timestamp"
    New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

    Write-Host ""
    Write-Host "==> Verifying Phase 10B migration" -ForegroundColor Cyan
    $migrationResult = Invoke-CapturedCommand `
        -Arguments @(
            "--yes", "supabase@latest", "migration", "list", "--linked"
        ) `
        -WorkingDirectory $root `
        -LogPrefix (Join-Path $logRoot "migration_list")
    $migrationOutput = [string]$migrationResult.Output
    $migrationRows = @(
        $migrationOutput -split "`r?`n" |
            Where-Object { $_ -match [regex]::Escape($migrationId) }
    )
    $confirmed = $migrationRows |
        Where-Object {
            [regex]::Matches(
                $_,
                [regex]::Escape($migrationId)
            ).Count -ge 2
        } |
        Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($confirmed)) {
        throw (
            "Migration $migrationId was not confirmed on the same " +
            "LOCAL/REMOTE row."
        )
    }
    Write-Host ("[ OK ] Migration row: " + $confirmed.Trim()) `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "==> Verifying admin-notifications Edge Function" `
        -ForegroundColor Cyan
    $functionResult = Invoke-CapturedCommand `
        -Arguments @(
            "--yes", "supabase@latest", "functions", "list",
            "--project-ref", $projectRef
        ) `
        -WorkingDirectory $root `
        -LogPrefix (Join-Path $logRoot "function_list")
    if ([string]$functionResult.Output -notmatch `
        [regex]::Escape($functionName)) {
        throw "The admin-notifications Edge Function was not found remotely."
    }
    Write-Host "[ OK ] Edge Function $functionName is deployed." `
        -ForegroundColor Green

    Write-Host ""
    Write-Host "==> Verifying Firebase server secret" -ForegroundColor Cyan
    $secretResult = Invoke-CapturedCommand `
        -Arguments @(
            "--yes", "supabase@latest", "secrets", "list",
            "--project-ref", $projectRef
        ) `
        -WorkingDirectory $root `
        -LogPrefix (Join-Path $logRoot "secret_list")
    if ([string]$secretResult.Output -notmatch [regex]::Escape($secretName)) {
        throw "The Firebase service-account server secret was not found."
    }
    Write-Host "[ OK ] Firebase service-account secret is present." `
        -ForegroundColor Green
    Write-Host "[ OK ] Verification logs: $logRoot" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
