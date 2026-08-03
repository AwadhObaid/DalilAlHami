[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRef = "xlsxhhzvwtatvtoqbxui"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectUrl = "https://$ProjectRef.supabase.co"
$googleCallback = "$projectUrl/auth/v1/callback"
$appRedirect = "com.awadhobaid.dalilalhami://login-callback/"

Write-Host ""
Write-Host "إعداد Google Auth – دليل الحامي" `
    -ForegroundColor Cyan
Write-Host "================================" `
    -ForegroundColor DarkCyan
Write-Host "Google Authorized redirect URI:" `
    -ForegroundColor Yellow
Write-Host $googleCallback -ForegroundColor White
Write-Host ""
Write-Host "Supabase Redirect URL:" `
    -ForegroundColor Yellow
Write-Host $appRedirect -ForegroundColor White
Write-Host ""
Write-Host "لا تضع Client Secret داخل Flutter أو Git." `
    -ForegroundColor Red
Write-Host ""

Start-Process `
    "https://supabase.com/dashboard/project/$ProjectRef/auth/providers?provider=Google"
Start-Sleep -Milliseconds 700
Start-Process `
    "https://supabase.com/dashboard/project/$ProjectRef/auth/url-configuration"
Start-Sleep -Milliseconds 700
Start-Process "https://console.cloud.google.com/auth/clients"
