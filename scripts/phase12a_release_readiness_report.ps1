param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [switch]$AutomatedValidationPassed
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Read-Text([string]$RelativePath) {
    $path = Join-Path $ProjectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return ""
    }
    return Get-Content -LiteralPath $path -Raw
}

function First-RegexGroup([string]$Text, [string]$Pattern) {
    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success -or $match.Groups.Count -lt 2) {
        return ""
    }
    return $match.Groups[1].Value
}

$pubspec = Read-Text "pubspec.yaml"
$gradle = Read-Text "android\app\build.gradle.kts"
$manifest = Read-Text "android\app\src\main\AndroidManifest.xml"
$firebaseOptions = Read-Text "lib\firebase_options.dart"
$gitignore = Read-Text ".gitignore"
$googleServicesPath = Join-Path $ProjectRoot "android\app\google-services.json"

$version = First-RegexGroup $pubspec '^version:\s*([^\r\n]+)'
$appId = First-RegexGroup $gradle 'applicationId\s*=\s*"([^"]+)"'
$namespace = First-RegexGroup $gradle 'namespace\s*=\s*"([^"]+)"'
$releaseUsesDebugSigning = $gradle -match 'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'
$placeholderPackage = $appId -match '^com\.example\.'
$iosFirebaseConfigured = $firebaseOptions -match 'case\s+TargetPlatform\.iOS:\s*return\s+ios;'
$oauthScheme = First-RegexGroup $manifest 'android:scheme="([^"]+)"\s*\r?\n\s*android:host="login-callback"'

$firebasePackage = ""
if (Test-Path -LiteralPath $googleServicesPath -PathType Leaf) {
    $google = Get-Content -LiteralPath $googleServicesPath -Raw | ConvertFrom-Json
    if ($null -ne $google.client -and $google.client.Count -gt 0) {
        $firebasePackage = [string]$google.client[0].client_info.android_client_info.package_name
    }
}

$branch = "unknown"
$commit = "unknown"
$tag = ""
$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($null -ne $gitCommand -and (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
    Push-Location $ProjectRoot
    try {
        $branchValue = (& git rev-parse --abbrev-ref HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($branchValue)) {
            $branch = $branchValue.Trim()
        }
        $commitValue = (& git rev-parse --short=12 HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($commitValue)) {
            $commit = $commitValue.Trim()
        }
        $tagValue = (& git describe --tags --exact-match HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($tagValue)) {
            $tag = $tagValue.Trim()
        }
    }
    finally {
        Pop-Location
    }
}

$blockers = New-Object System.Collections.Generic.List[string]
if ($placeholderPackage) {
    $blockers.Add("Android applicationId still uses the com.example placeholder namespace.")
}
if ($releaseUsesDebugSigning) {
    $blockers.Add("Android release build still uses the debug signing configuration.")
}
if (-not $gitignore.Contains("android/key.properties") -or -not $gitignore.Contains("*.jks")) {
    $blockers.Add("Git ignore rules for Android signing material are incomplete.")
}
if (-not [string]::IsNullOrWhiteSpace($firebasePackage) -and $firebasePackage -ne $appId) {
    $blockers.Add("Firebase Android package does not match the Gradle applicationId.")
}

$notes = New-Object System.Collections.Generic.List[string]
if (-not $iosFirebaseConfigured) {
    $notes.Add("Firebase options are not configured for iOS in the current baseline.")
}
if (-not [string]::IsNullOrWhiteSpace($oauthScheme)) {
    $notes.Add("Supabase Google OAuth callback scheme: ${oauthScheme}://login-callback/")
}
if ($placeholderPackage -and -not [string]::IsNullOrWhiteSpace($firebasePackage)) {
    $notes.Add("Changing applicationId in Phase 12B requires a matching Firebase Android app configuration.")
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Dalil Al Hami - Phase 12A Release Readiness Report")
$lines.Add("Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss K'))")
$lines.Add("")
$lines.Add("Automated validation: $(if ($AutomatedValidationPassed) { 'PASSED' } else { 'NOT CONFIRMED' })")
$lines.Add("Project version: $version")
$lines.Add("Git branch: $branch")
$lines.Add("Git commit: $commit")
if (-not [string]::IsNullOrWhiteSpace($tag)) {
    $lines.Add("Git tag: $tag")
}
$lines.Add("Android namespace: $namespace")
$lines.Add("Android applicationId: $appId")
$lines.Add("Firebase Android package: $firebasePackage")
$lines.Add("Release signing uses debug key: $releaseUsesDebugSigning")
$lines.Add("iOS Firebase configured: $iosFirebaseConfigured")
$lines.Add("")
$lines.Add("Phase 12B blockers: $($blockers.Count)")
if ($blockers.Count -eq 0) {
    $lines.Add("- None detected by the Phase 12A static report.")
}
else {
    foreach ($item in $blockers) {
        $lines.Add("- $item")
    }
}
$lines.Add("")
$lines.Add("Platform/release notes:")
if ($notes.Count -eq 0) {
    $lines.Add("- None.")
}
else {
    foreach ($item in $notes) {
        $lines.Add("- $item")
    }
}
$lines.Add("")
$lines.Add("Interpretation:")
if ($AutomatedValidationPassed) {
    $lines.Add("- Analyzer, localization contracts, regression tests, secret checks, and the release-mode QA build passed.")
}
$lines.Add("- Phase 12A validates application stability; it does not make the current APK publishable.")
$lines.Add("- Resolve all Phase 12B blockers before generating the production AAB/APK.")

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}
[System.IO.File]::WriteAllLines($OutputPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[ OK ] Release readiness report: $OutputPath" -ForegroundColor Green
