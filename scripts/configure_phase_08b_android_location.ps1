[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $manifestPath = Join-Path $resolvedRoot `
        "android\app\src\main\AndroidManifest.xml"
    $valuesDirectory = Join-Path $resolvedRoot `
        "android\app\src\main\res\values"
    $stringsPath = Join-Path $valuesDirectory "strings.xml"

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "AndroidManifest.xml was not found."
    }

    # Windows PowerShell 5.1 treats UTF-8 files without BOM as ANSI unless the
    # encoding is explicit. Reading and writing explicitly prevents Arabic text
    # in the manifest from being converted to mojibake.
    $content = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
    $permissions = @(
        '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />',
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />'
    )

    foreach ($permission in $permissions) {
        $permissionName = [regex]::Match(
            $permission,
            'android:name="([^"]+)"'
        ).Groups[1].Value
        if ($content -notmatch [regex]::Escape($permissionName)) {
            $applicationIndex = $content.IndexOf("<application")
            if ($applicationIndex -lt 0) {
                throw "The Android application element was not found."
            }
            $content = $content.Insert(
                $applicationIndex,
                "    $permission`r`n"
            )
        }
    }

    $applicationMatch = [regex]::Match(
        $content,
        '<application\b[^>]*>',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    if (-not $applicationMatch.Success) {
        throw "The Android application element was not found."
    }

    $applicationTag = $applicationMatch.Value
    if ($applicationTag -match 'android:label\s*=\s*"[^"]*"') {
        $updatedApplicationTag = [regex]::Replace(
            $applicationTag,
            'android:label\s*=\s*"[^"]*"',
            'android:label="@string/app_name"',
            1
        )
    }
    else {
        $updatedApplicationTag = $applicationTag.Replace(
            '<application',
            '<application android:label="@string/app_name"'
        )
    }
    $content = $content.Remove(
        $applicationMatch.Index,
        $applicationMatch.Length
    ).Insert(
        $applicationMatch.Index,
        $updatedApplicationTag
    )

    New-Item -ItemType Directory -Path $valuesDirectory -Force | Out-Null

    # Numeric XML entities keep the resource ASCII-only while Android renders
    # the exact Arabic application name: Dalil Al Hami.
    $stringsXml = @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">&#x062F;&#x0644;&#x064A;&#x0644; &#x0627;&#x0644;&#x062D;&#x0627;&#x0645;&#x064A;</string>
</resources>
'@

    [System.IO.File]::WriteAllText(
        $manifestPath,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $stringsPath,
        $stringsXml,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host "[ OK ] Android location permissions and application label are configured." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
