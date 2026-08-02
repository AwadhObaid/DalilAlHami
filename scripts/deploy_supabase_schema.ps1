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

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$migrationsPath = Join-Path $resolvedProjectRoot "supabase\migrations"

if (-not (Test-Path -LiteralPath $migrationsPath -PathType Container)) {
    throw "لم يتم العثور على supabase\migrations."
}

$nodeVersionText = (& node --version 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($nodeVersionText)) {
    throw "Node.js غير مثبت أو غير موجود في PATH."
}

$majorVersion = [int](($nodeVersionText.TrimStart('v') -split '\.')[0])
if ($majorVersion -lt 20) {
    throw "Supabase CLI عبر npx يحتاج Node.js 20 أو أحدث. الإصدار الحالي: $nodeVersionText"
}

Push-Location $resolvedProjectRoot
try {
    if (-not (Test-Path -LiteralPath ".\supabase\config.toml")) {
        Write-Host ""
        Write-Host "==> تهيئة Supabase CLI" -ForegroundColor Cyan
        Invoke-Checked -Label "supabase init" -Command {
            npx --yes supabase@latest init
        }
    }

    Write-Host ""
    Write-Host "==> تسجيل الدخول إلى Supabase" -ForegroundColor Cyan
    Write-Host "سيفتح المتصفح أو يطلب Access Token حسب إعداد CLI." -ForegroundColor Yellow
    Invoke-Checked -Label "supabase login" -Command {
        npx --yes supabase@latest login
    }

    Write-Host ""
    Write-Host "==> ربط المشروع المحلي بالمشروع السحابي" -ForegroundColor Cyan
    Invoke-Checked -Label "supabase link" -Command {
        npx --yes supabase@latest link --project-ref $ProjectRef
    }

    Write-Host ""
    Write-Host "==> معاينة المهاجرات قبل التطبيق" -ForegroundColor Cyan
    Invoke-Checked -Label "supabase db push --dry-run" -Command {
        npx --yes supabase@latest db push --dry-run
    }

    Write-Host ""
    $confirmation = Read-Host "اكتب APPLY لتطبيق الجداول والسياسات على مشروع Supabase"

    if ($confirmation -cne "APPLY") {
        Write-Host "[WARN] لم يتم تطبيق المهاجرات." -ForegroundColor Yellow
        exit 0
    }

    Write-Host ""
    Write-Host "==> تطبيق المهاجرات" -ForegroundColor Cyan
    Invoke-Checked -Label "supabase db push" -Command {
        npx --yes supabase@latest db push
    }

    Write-Host ""
    Write-Host "[ OK ] تم تطبيق مخطط دليل الحامي على Supabase." -ForegroundColor Green
}
finally {
    Pop-Location
}
