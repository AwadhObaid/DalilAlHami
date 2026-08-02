[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",

    [ValidateNotNullOrEmpty()]
    [string]$DeviceId = "de6ec47c8024"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$localConfigPath = Join-Path $resolvedProjectRoot ".supabase.local.ps1"

if (-not (Test-Path -LiteralPath $localConfigPath -PathType Leaf)) {
    throw "لم يتم العثور على .supabase.local.ps1. شغّل scripts\configure_supabase.ps1 أولًا."
}

. $localConfigPath

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
    throw "SupabaseUrl فارغ."
}

if ([string]::IsNullOrWhiteSpace($SupabasePublishableKey)) {
    throw "SupabasePublishableKey فارغ."
}

Push-Location $resolvedProjectRoot
try {
    flutter run -d $DeviceId `
        --dart-define="SUPABASE_URL=$SupabaseUrl" `
        --dart-define="SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"

    if ($LASTEXITCODE -ne 0) {
        throw "flutter run failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}
