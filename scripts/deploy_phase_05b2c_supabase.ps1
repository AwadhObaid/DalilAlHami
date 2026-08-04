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
        "supabase\migrations\20260804174500_multi_business_per_owner.sql"
    $linkedRefPath = Join-Path $resolvedRoot "supabase\.temp\project-ref"

    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "Phase 05B-2C migration was not found."
    }
    if (-not (Test-Path -LiteralPath $linkedRefPath -PathType Leaf)) {
        throw "The Supabase project is not linked."
    }

    Write-Host ""
    Write-Host "==> Applying Phase 05B-2C Supabase migration" `
        -ForegroundColor Cyan
    Write-Host (
        "Choose Yes when Supabase asks to apply 20260804174500_multi_business_per_owner.sql."
    ) -ForegroundColor Yellow

    $process = Start-Process `
        -FilePath "npx.cmd" `
        -ArgumentList @(
            "--yes", "supabase@latest", "db", "push", "--linked"
        ) `
        -WorkingDirectory $resolvedRoot `
        -NoNewWindow `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Supabase db push failed with exit code $($process.ExitCode)."
    }

    Write-Host "[ OK ] Multi-business migration was pushed." `
        -ForegroundColor Green
    Write-Host "[ OK ] Docker catalog warnings can be ignored." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
