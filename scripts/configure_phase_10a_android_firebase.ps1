[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Content, $encoding)
}

try {
    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $settingsPath = Join-Path $root "android\settings.gradle.kts"
    $appGradlePath = Join-Path $root "android\app\build.gradle.kts"
    $manifestPath = Join-Path $root `
        "android\app\src\main\AndroidManifest.xml"

    foreach ($path in @($settingsPath, $appGradlePath, $manifestPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required Android file is missing: $path"
        }
    }

    $settingsLines = @(Get-Content -LiteralPath $settingsPath -Encoding UTF8)
    $googlePlugin = `
        '    id("com.google.gms.google-services") version "4.5.0" apply false'
    if (($settingsLines -join "`n") -notmatch `
        [regex]::Escape('id("com.google.gms.google-services")')) {
        $updated = @()
        $inserted = $false
        foreach ($line in $settingsLines) {
            $updated += $line
            if (-not $inserted -and
                $line -match 'id\("com\.android\.application"\)') {
                $updated += $googlePlugin
                $inserted = $true
            }
        }
        if (-not $inserted) {
            throw "Could not find the Android application plugin anchor."
        }
        Write-Utf8NoBom -Path $settingsPath `
            -Content (($updated -join "`r`n") + "`r`n")
    }

    $appLines = @(Get-Content -LiteralPath $appGradlePath -Encoding UTF8)
    $appPlugin = '    id("com.google.gms.google-services")'
    if (($appLines -join "`n") -notmatch `
        [regex]::Escape('id("com.google.gms.google-services")')) {
        $updated = @()
        $inserted = $false
        foreach ($line in $appLines) {
            $updated += $line
            if (-not $inserted -and
                $line -match '^\s*id\("com\.android\.application"\)') {
                $updated += $appPlugin
                $inserted = $true
            }
        }
        if (-not $inserted) {
            throw "Could not find the app Gradle plugin anchor."
        }
        Write-Utf8NoBom -Path $appGradlePath `
            -Content (($updated -join "`r`n") + "`r`n")
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    $channelKey = `
        'com.google.firebase.messaging.default_notification_channel_id'
    if ($manifest -notmatch [regex]::Escape($channelKey)) {
        $metadata = @"

        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/launcher_icon" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="dalil_alhami_push" />
"@
        $applicationClose = "    </application>"
        if ($manifest -notmatch [regex]::Escape($applicationClose)) {
            throw "Could not find the Android application closing tag."
        }
        $manifest = $manifest.Replace(
            $applicationClose,
            $metadata + "`r`n" + $applicationClose
        )
        Write-Utf8NoBom -Path $manifestPath -Content $manifest
    }

    Write-Host "[ OK ] Android Firebase Gradle and FCM metadata configured." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
