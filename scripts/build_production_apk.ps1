param(
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean"
)

$ErrorActionPreference = "Stop"

$ExpectedSignerSha256 = "5B630A18CD75E7A86D530F5FFE5501FEB2453B76137EA5DFFF37150807969124"

function Convert-SecureToPlain([Security.SecureString]$Secure) {
    $Bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
    }
}

function Find-ApkSigner {
    $SdkRoots = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($Sdk in $SdkRoots) {
        $BuildTools = Join-Path $Sdk "build-tools"
        if (-not (Test-Path $BuildTools)) { continue }

        foreach ($Dir in (Get-ChildItem $BuildTools -Directory | Sort-Object Name -Descending)) {
            $Candidate = Join-Path $Dir.FullName "apksigner.bat"
            if (Test-Path $Candidate) { return $Candidate }
        }
    }

    throw "apksigner.bat was not found."
}

Set-Location $ProjectRoot

if (-not (Test-Path ".\.supabase.local.ps1" -PathType Leaf)) {
    throw ".supabase.local.ps1 was not found."
}

. ".\.supabase.local.ps1"

$SecurePassword = Read-Host "APP SIGNING keystore password" -AsSecureString
$PlainPassword = Convert-SecureToPlain $SecurePassword

try {
    $env:DALIL_SIGNING_MODE = "app"
    $env:DALIL_APP_STORE_PASSWORD = $PlainPassword
    $env:DALIL_APP_KEY_PASSWORD = $PlainPassword

    flutter build apk `
        --release `
        --target-platform android-arm64 `
        --dart-define="SUPABASE_URL=$SupabaseUrl" `
        --dart-define="SUPABASE_PUBLISHABLE_KEY=$SupabasePublishableKey"

    if ($LASTEXITCODE -ne 0) {
        throw "Production APK build failed."
    }

    $BuildDir = Join-Path $ProjectRoot "build\app\outputs\flutter-apk"
    $SourceApk = Join-Path $BuildDir "app-release.apk"
    $OutputApk = Join-Path $BuildDir "DalilAlHami-production-arm64.apk"

    if (-not (Test-Path $SourceApk -PathType Leaf)) {
        throw "app-release.apk was not found."
    }

    Copy-Item -LiteralPath $SourceApk -Destination $OutputApk -Force

    $ApkSigner = Find-ApkSigner

    $PreviousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $SignerOutput = @(& $ApkSigner verify --print-certs $OutputApk 2>&1)
        $SignerExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($SignerExitCode -ne 0) {
        throw "apksigner verification failed."
    }

    $ShaLine = $SignerOutput |
        Where-Object { $_ -match "Signer #1 certificate SHA-256 digest:" } |
        Select-Object -First 1

    if (-not $ShaLine) {
        throw "APK signer SHA-256 was not found."
    }

    $SignerSha256 = (($ShaLine -split ":", 2)[1] -replace "[^0-9A-Fa-f]", "").ToUpperInvariant()

    if ($SignerSha256 -ne $ExpectedSignerSha256) {
        throw "APK is NOT signed by the expected production app signing certificate."
    }

    $FileSha256 = (Get-FileHash -LiteralPath $OutputApk -Algorithm SHA256).Hash.ToLowerInvariant()

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "[ OK ] Production APK built and signer verified." -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK: $OutputApk" -ForegroundColor Cyan
    Write-Host "APK file SHA-256: $FileSha256" -ForegroundColor Cyan
    Write-Host "Signer SHA-256: $SignerSha256" -ForegroundColor Cyan
}
finally {
    Remove-Item Env:DALIL_SIGNING_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:DALIL_APP_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:DALIL_APP_KEY_PASSWORD -ErrorAction SilentlyContinue
    $PlainPassword = $null
}