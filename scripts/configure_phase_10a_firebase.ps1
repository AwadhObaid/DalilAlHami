[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",
    [string]$FirebaseProjectId = "",
    [ValidateNotNullOrEmpty()]
    [string]$AndroidPackageName = "com.awadhobaid.dalilalhami"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-External {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][scriptblock]$Command
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

try {
    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $toolsRoot = Join-Path ([IO.Path]::GetTempPath()) `
        "DalilAlHami_Phase10A_FirebaseCli"
    New-Item -ItemType Directory -Path $toolsRoot -Force | Out-Null

    if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) {
        throw "Node.js is required for the Firebase CLI."
    }
    if (-not (Get-Command npx.cmd -ErrorAction SilentlyContinue)) {
        throw "npx.cmd is required for the Firebase CLI."
    }
    $dartCommand = Get-Command dart.exe -ErrorAction SilentlyContinue
    $dartPath = if ($null -ne $dartCommand) {
        [string]$dartCommand.Source
    }
    else {
        $null
    }

    if ([string]::IsNullOrWhiteSpace($dartPath)) {
        $flutterCommand = Get-Command flutter.bat -ErrorAction SilentlyContinue
        if ($null -eq $flutterCommand) {
            $flutterCommand = Get-Command flutter.exe -ErrorAction SilentlyContinue
        }
        if ($null -eq $flutterCommand) {
            $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        }

        if ($null -ne $flutterCommand) {
            $flutterBin = Split-Path -Parent ([string]$flutterCommand.Source)
            $bundledDart = Join-Path $flutterBin "cache\dart-sdk\bin\dart.exe"
            if (Test-Path -LiteralPath $bundledDart -PathType Leaf) {
                $dartPath = $bundledDart
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($dartPath)) {
        $commonFlutterRoots = @(
            (Join-Path $env:USERPROFILE "develop\flutter"),
            (Join-Path $env:USERPROFILE "flutter"),
            "C:\src\flutter",
            "C:\flutter"
        )
        foreach ($flutterRoot in $commonFlutterRoots) {
            $candidate = Join-Path $flutterRoot "bin\cache\dart-sdk\bin\dart.exe"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $dartPath = $candidate
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($dartPath) -or
        -not (Test-Path -LiteralPath $dartPath -PathType Leaf)) {
        throw (
            "Dart could not be resolved. Flutter normally includes Dart. " +
            "Verify that flutter works, then re-run this installer."
        )
    }

    $dartBin = Split-Path -Parent $dartPath
    $env:PATH = "$dartBin;$env:PATH"
    Write-Host "[ OK ] Dart: $dartPath" -ForegroundColor Green

    $firebaseCommand = Get-Command firebase.cmd -ErrorAction SilentlyContinue
    if ($null -eq $firebaseCommand) {
        $wrapperPath = Join-Path $toolsRoot "firebase.cmd"
        @(
            "@echo off"
            "npx.cmd --yes firebase-tools@latest %*"
        ) | Set-Content -LiteralPath $wrapperPath -Encoding ASCII
        $env:PATH = "$toolsRoot;$env:PATH"
        $firebaseCommand = Get-Command firebase.cmd -ErrorAction Stop
    }

    $firebasePath = [string]$firebaseCommand.Source

    Write-Host ""
    Write-Host "==> Checking Firebase CLI login" -ForegroundColor Cyan
    Invoke-External -Label "Firebase login" -Command {
        & $firebasePath login
    }

    Write-Host ""
    Write-Host "==> Installing or updating FlutterFire CLI" -ForegroundColor Cyan
    Invoke-External -Label "FlutterFire CLI activation" -Command {
        & $dartPath pub global activate flutterfire_cli
    }

    $pubCacheBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
    if (Test-Path -LiteralPath $pubCacheBin -PathType Container) {
        $env:PATH = "$pubCacheBin;$toolsRoot;$env:PATH"
    }

    $flutterFire = Get-Command flutterfire.bat -ErrorAction SilentlyContinue
    if ($null -eq $flutterFire) {
        $flutterFire = Get-Command flutterfire -ErrorAction SilentlyContinue
    }
    if ($null -eq $flutterFire) {
        throw "flutterfire executable was not found after activation."
    }
    $flutterFirePath = [string]$flutterFire.Source

    $arguments = @(
        "configure",
        "--platforms=android",
        "--android-package-name=$AndroidPackageName",
        "--android-out=android/app/google-services.json",
        "--out=lib/firebase_options.dart"
    )

    if (-not [string]::IsNullOrWhiteSpace($FirebaseProjectId)) {
        $arguments += "--yes"
        $arguments += "--project=$($FirebaseProjectId.Trim())"
        Write-Host ""
        Write-Host "==> Configuring the requested Firebase project" `
            -ForegroundColor Cyan
    }
    else {
        Write-Host ""
        Write-Host "==> Selecting or creating the Firebase project" `
            -ForegroundColor Cyan
        Write-Host (
            "FlutterFire will ask you to select an existing Firebase " +
            "project or create one. Configure Android only."
        ) -ForegroundColor Yellow
    }

    Push-Location $root
    try {
        Invoke-External -Label "flutterfire configure" -Command {
            & $flutterFirePath @arguments
        }
    }
    finally {
        Pop-Location
    }

    $optionsPath = Join-Path $root "lib\firebase_options.dart"
    $googleServicesPath = Join-Path $root `
        "android\app\google-services.json"
    if (-not (Test-Path -LiteralPath $optionsPath -PathType Leaf)) {
        throw "FlutterFire did not create lib/firebase_options.dart."
    }
    if (-not (Test-Path -LiteralPath $googleServicesPath -PathType Leaf)) {
        throw "FlutterFire did not create android/app/google-services.json."
    }

    Write-Host "[ OK ] Firebase Android configuration generated." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
