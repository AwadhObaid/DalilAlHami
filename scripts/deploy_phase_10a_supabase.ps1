[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationName = `
        "20260807133000_firebase_push_notification_foundation.sql"
    $migrationPath = Join-Path $root "supabase\migrations\$migrationName"
    $linkedRefPath = Join-Path $root "supabase\.temp\project-ref"

    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "Phase 10A Supabase migration was not found."
    }
    if (-not (Test-Path -LiteralPath $linkedRefPath -PathType Leaf)) {
        throw (
            "The Supabase project is not linked. Run npx supabase link " +
            "from the Flutter project root."
        )
    }

    Write-Host ""
    Write-Host "==> Applying Phase 10A Supabase migration" `
        -ForegroundColor Cyan
    Write-Host (
        "Confirm the migration when Supabase asks to apply " +
        $migrationName + "."
    ) -ForegroundColor Yellow

    Push-Location $root
    try {
        & npx.cmd --yes supabase@latest db push --linked
        if ($LASTEXITCODE -ne 0) {
            throw "Supabase db push failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "[ OK ] Phase 10A migration was pushed." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
