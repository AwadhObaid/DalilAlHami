[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]{15,30}$')]
    [string]$ProjectRef,

    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][scriptblock]$Command
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

try {
    $resolvedProjectRoot =
        (Resolve-Path -LiteralPath $ProjectRoot).Path
    $migrationPath = Join-Path $resolvedProjectRoot `
        "supabase\migrations\20260802213000_prepare_directory_read.sql"

    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "ملف Migration الخاص بالمرحلة 03B غير موجود."
    }

    $nodeVersionText = (& node --version 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "Node.js غير موجود في PATH."
    }

    $majorVersion = [int](
        ($nodeVersionText.TrimStart('v') -split '\.')[0]
    )

    if ($majorVersion -lt 20) {
        throw "يتطلب Supabase CLI إصدار Node.js 20 أو أحدث."
    }

    Push-Location $resolvedProjectRoot
    try {
        Write-Host ""
        Write-Host "==> ربط المشروع السحابي" -ForegroundColor Cyan
        Invoke-Checked -Label "supabase link" -Command {
            npx --yes supabase@latest link `
                --project-ref $ProjectRef
        }

        Write-Host ""
        Write-Host "==> معاينة Migration المرحلة 03B" `
            -ForegroundColor Cyan
        Invoke-Checked -Label "supabase db push --dry-run" -Command {
            npx --yes supabase@latest db push --dry-run
        }

        Write-Host ""
        $confirmation = Read-Host `
            "اكتب APPLY لتطبيق المرحلة 03B على Supabase"

        if ($confirmation -cne "APPLY") {
            Write-Host "[WARN] تم إلغاء التطبيق." `
                -ForegroundColor Yellow
            exit 0
        }

        Write-Host ""
        Write-Host "==> تطبيق Migration المرحلة 03B" `
            -ForegroundColor Cyan
        Invoke-Checked -Label "supabase db push" -Command {
            npx --yes supabase@latest db push
        }

        Write-Host ""
        Write-Host "[ OK ] تم تطبيق قاعدة بيانات المرحلة 03B." `
            -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" `
        -ForegroundColor Red
    exit 1
}
