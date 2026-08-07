[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationName = "20260807030000_admin_user_management.sql"
    $migrationPath = Join-Path $resolvedRoot `
        "supabase\migrations\$migrationName"
    $functionPath = Join-Path $resolvedRoot `
        "supabase\functions\admin-users\index.ts"
    $linkedRefPath = Join-Path $resolvedRoot "supabase\.temp\project-ref"

    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "Phase 08C migration was not found."
    }
    if (-not (Test-Path -LiteralPath $functionPath -PathType Leaf)) {
        throw "The admin-users Edge Function was not found."
    }
    if (-not (Test-Path -LiteralPath $linkedRefPath -PathType Leaf)) {
        throw (
            "The Supabase project is not linked. " +
            "Run npx supabase link from the Flutter project root."
        )
    }

    $projectRef = (Get-Content -LiteralPath $linkedRefPath `
        -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($projectRef)) {
        throw "The linked Supabase project reference is empty."
    }

    Write-Host ""
    Write-Host "==> Applying Phase 08C Supabase migration" `
        -ForegroundColor Cyan
    Write-Host (
        "Confirm the migration when Supabase asks to apply " +
        $migrationName + "."
    ) -ForegroundColor Yellow

    Push-Location $resolvedRoot
    try {
        & npx.cmd --yes supabase@latest db push --linked
        if ($LASTEXITCODE -ne 0) {
            throw "Supabase db push failed with exit code $LASTEXITCODE."
        }

        Write-Host ""
        Write-Host "==> Deploying the admin-users Edge Function" `
            -ForegroundColor Cyan
        & npx.cmd --yes supabase@latest functions deploy `
            admin-users `
            --project-ref $projectRef `
            --use-api
        if ($LASTEXITCODE -ne 0) {
            throw (
                "Supabase function deploy failed with exit code " +
                "$LASTEXITCODE."
            )
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "[ OK ] Phase 08C migration was pushed." `
        -ForegroundColor Green
    Write-Host "[ OK ] admin-users Edge Function was deployed." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
