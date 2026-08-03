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
        "supabase\migrations\20260802224500_google_auth_profile_sync.sql"

    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "ملف Migration الخاص بتسجيل Google غير موجود."
    }

    Push-Location $resolvedProjectRoot
    try {
        Write-Host ""
        Write-Host "==> ربط مشروع Supabase" -ForegroundColor Cyan
        Invoke-Checked -Label "supabase link" -Command {
            npx --yes supabase@latest link `
                --project-ref $ProjectRef
        }

        Write-Host ""
        Write-Host "==> معاينة Migration تسجيل Google" `
            -ForegroundColor Cyan
        Invoke-Checked -Label "supabase db push --dry-run" -Command {
            npx --yes supabase@latest db push --dry-run
        }

        Write-Host ""
        $confirmation = Read-Host `
            "اكتب APPLY لتطبيق مزامنة Google على Supabase"

        if ($confirmation -cne "APPLY") {
            Write-Host "[WARN] تم إلغاء التطبيق." `
                -ForegroundColor Yellow
            exit 0
        }

        Write-Host ""
        Write-Host "==> تطبيق Migration تسجيل Google" `
            -ForegroundColor Cyan
        Invoke-Checked -Label "supabase db push" -Command {
            npx --yes supabase@latest db push
        }

        Write-Host ""
        Write-Host "[ OK ] تم تطبيق مزامنة ملفات Google." `
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
