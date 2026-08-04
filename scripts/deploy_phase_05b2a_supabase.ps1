[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationPath = Join-Path $resolvedRoot `
        "supabase\migrations\20260804003000_offline_sync_queue.sql"
    $linkedRefPath = Join-Path $resolvedRoot "supabase\.temp\project-ref"

    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "Phase 05B-2A migration was not found."
    }
    if (-not (Test-Path -LiteralPath $linkedRefPath -PathType Leaf)) {
        throw (
            "The Supabase project is not linked. Run " +
            "npx --yes supabase@latest link --project-ref YOUR_REF first."
        )
    }

    Write-Host "" 
    Write-Host "==> Applying Phase 05B-2A Supabase migration" `
        -ForegroundColor Cyan
    Write-Host (
        "Supabase may ask for confirmation. Choose Yes to apply " +
        "20260804003000_offline_sync_queue.sql."
    ) -ForegroundColor Yellow

    $process = Start-Process `
        -FilePath "npx.cmd" `
        -ArgumentList @(
            "--yes",
            "supabase@latest",
            "db",
            "push",
            "--linked"
        ) `
        -WorkingDirectory $resolvedRoot `
        -NoNewWindow `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Supabase db push failed with exit code $($process.ExitCode)."
    }

    Write-Host (
        "[ OK ] Supabase db push completed. " +
        "Docker catalog warnings can be ignored."
    ) -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
