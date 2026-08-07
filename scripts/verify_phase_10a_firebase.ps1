[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",
    [ValidateNotNullOrEmpty()]
    [string]$AndroidPackageName = "com.example.dalilalhami"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $optionsPath = Join-Path $root "lib\firebase_options.dart"
    $googleServicesPath = Join-Path $root `
        "android\app\google-services.json"
    $settingsPath = Join-Path $root "android\settings.gradle.kts"
    $appGradlePath = Join-Path $root "android\app\build.gradle.kts"
    $manifestPath = Join-Path $root `
        "android\app\src\main\AndroidManifest.xml"

    foreach ($path in @(
        $optionsPath,
        $googleServicesPath,
        $settingsPath,
        $appGradlePath,
        $manifestPath
    )) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Firebase verification file is missing: $path"
        }
    }

    $json = Get-Content -LiteralPath $googleServicesPath `
        -Raw -Encoding UTF8 | ConvertFrom-Json
    $packageNames = @(
        $json.client |
            ForEach-Object {
                $_.client_info.android_client_info.package_name
            }
    )
    if ($packageNames -notcontains $AndroidPackageName) {
        throw (
            "google-services.json does not contain Android package " +
            "$AndroidPackageName."
        )
    }

    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8
    if ($settings -notmatch [regex]::Escape(
        'id("com.google.gms.google-services") version "4.5.0"')) {
        throw "The Google services Gradle plugin version is missing."
    }

    $appGradle = Get-Content -LiteralPath $appGradlePath -Raw -Encoding UTF8
    if ($appGradle -notmatch [regex]::Escape(
        'id("com.google.gms.google-services")')) {
        throw "The app-level Google services Gradle plugin is missing."
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    if ($manifest -notmatch "dalil_alhami_push") {
        throw "The default FCM notification channel metadata is missing."
    }

    $projectId = [string]$json.project_info.project_id
    Write-Host "[ OK ] Firebase project: $projectId" `
        -ForegroundColor Green
    Write-Host "[ OK ] Android package: $AndroidPackageName" `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
