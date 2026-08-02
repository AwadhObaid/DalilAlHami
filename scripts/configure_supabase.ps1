[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://[a-zA-Z0-9-]+\.supabase\.co/?$')]
    [string]$SupabaseUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PublishableKey,

    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$localConfigPath = Join-Path $resolvedProjectRoot ".supabase.local.ps1"
$gitIgnorePath = Join-Path $resolvedProjectRoot ".gitignore"

$escapedUrl = $SupabaseUrl.TrimEnd('/').Replace("'", "''")
$escapedKey = $PublishableKey.Trim().Replace("'", "''")

@"
`$SupabaseUrl = '$escapedUrl'
`$SupabasePublishableKey = '$escapedKey'
"@ | Set-Content -LiteralPath $localConfigPath -Encoding UTF8

$ignoreEntry = ".supabase.local.ps1"
$gitIgnoreContent = @()

if (Test-Path -LiteralPath $gitIgnorePath) {
    $gitIgnoreContent = @(Get-Content -LiteralPath $gitIgnorePath)
}

if ($gitIgnoreContent -notcontains $ignoreEntry) {
    Add-Content -LiteralPath $gitIgnorePath -Value "`n# Local Supabase client configuration"
    Add-Content -LiteralPath $gitIgnorePath -Value $ignoreEntry
}

Write-Host ""
Write-Host "[ OK ] تم حفظ إعداد Supabase المحلي:" -ForegroundColor Green
Write-Host $localConfigPath -ForegroundColor Yellow
Write-Host ""
Write-Host "ملاحظة: لم يتم حفظ service_role أو كلمة مرور قاعدة البيانات." -ForegroundColor Cyan
