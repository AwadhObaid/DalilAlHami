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
        "supabase\migrations\20260805234500_admin_business_review_workflow.sql"
    $linkedRefPath = Join-Path $resolvedRoot "supabase\.temp\project-ref"

    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "Phase 07B migration was not found."
    }
    if (-not (Test-Path -LiteralPath $linkedRefPath -PathType Leaf)) {
        throw (
            "The Supabase project is not linked. " +
            "Run npx supabase link before installing Phase 07B."
        )
    }

    $projectRef = (
        Get-Content -LiteralPath $linkedRefPath -Raw
    ).Trim()
    if ([string]::IsNullOrWhiteSpace($projectRef)) {
        throw "The linked Supabase project reference is empty."
    }

    Write-Host ""
    Write-Host "==> Applying Phase 07B Supabase migration" `
        -ForegroundColor Cyan
    Write-Host (
        "Confirm the migration when Supabase asks to apply " +
        "20260805234500_admin_business_review_workflow.sql."
    ) -ForegroundColor Yellow
    Write-Host "[ OK ] Linked Supabase project detected." `
        -ForegroundColor Green

    Push-Location $resolvedRoot
    try {
        & npx.cmd --yes supabase@latest db push --linked
        if ($LASTEXITCODE -ne 0) {
            throw (
                "Supabase db push failed with exit code " +
                "$LASTEXITCODE."
            )
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "[ OK ] Phase 07B migration was pushed." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
