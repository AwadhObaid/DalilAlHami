param(
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",
    [string]$SigningRoot = "F:\DalilAlHami_Signing_PRIVATE"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$BaseZip = Join-Path $ProjectRoot "build\app\intermediates\module_bundle\release\buildReleasePreBundle\base.zip"
$ToolDir = Join-Path $SigningRoot "tools"
$BundletoolJar = Join-Path $ToolDir "bundletool-all-1.18.3.jar"
$UploadKeyStore = Join-Path $SigningRoot "dalilalhami-upload.jks"
$UploadAlias = "dalilalhami_upload"
$OutputDir = Join-Path $ProjectRoot "build\app\outputs\bundle\manual"
$OutputAab = Join-Path $OutputDir "DalilAlHami-play-upload-manual.aab"
$ExpectedUploadSha256 = "BE661FE2D0D77D41E447BCAE688335E3FCB03F9FB348700C76165B19D26254B2"

function Fail([string]$Message) { throw $Message }

Set-Location $ProjectRoot

if (-not (Test-Path $BaseZip -PathType Leaf)) {
    Fail "base.zip is missing. This helper intentionally does not rebuild Flutter/Gradle. Expected: $BaseZip"
}

if (-not (Test-Path $UploadKeyStore -PathType Leaf)) {
    Fail "Play upload keystore is missing: $UploadKeyStore"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Zip = [System.IO.Compression.ZipFile]::OpenRead($BaseZip)
try {
    $DexNames = @(
        $Zip.Entries |
        Where-Object { $_.FullName -match '^dex/classes([0-9]+)?\.dex$' } |
        ForEach-Object { $_.FullName }
    )

    if ($DexNames -notcontains "dex/classes.dex") {
        Fail "base.zip is missing dex/classes.dex."
    }
}
finally {
    $Zip.Dispose()
}

New-Item -ItemType Directory -Path $ToolDir -Force | Out-Null

if (-not (Test-Path $BundletoolJar -PathType Leaf)) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Fail "bundletool 1.18.3 is missing and GitHub CLI (gh) is unavailable."
    }

    gh release download "1.18.3" `
        --repo "google/bundletool" `
        --pattern "bundletool-all-1.18.3.jar" `
        --dir "$ToolDir"

    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to download official bundletool 1.18.3."
    }
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Remove-Item -LiteralPath $OutputAab -Force -ErrorAction SilentlyContinue

$OldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & java -jar "$BundletoolJar" build-bundle `
        "--modules=$BaseZip" `
        "--output=$OutputAab"
    $BuildExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $OldPreference
}

if ($BuildExit -ne 0 -or -not (Test-Path $OutputAab -PathType Leaf)) {
    Fail "Standalone bundletool failed to create the AAB."
}

Write-Host ""
Write-Host "Enter the PLAY UPLOAD keystore password when jarsigner prompts." -ForegroundColor Yellow

$OldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & jarsigner `
        -sigalg SHA256withRSA `
        -digestalg SHA-256 `
        -keystore "$UploadKeyStore" `
        "$OutputAab" `
        "$UploadAlias"
    $SignExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $OldPreference
}

if ($SignExit -ne 0) {
    Fail "AAB signing failed."
}

$OldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    & java -jar "$BundletoolJar" validate "--bundle=$OutputAab"
    $ValidateExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $OldPreference
}

if ($ValidateExit -ne 0) {
    Fail "bundletool validate rejected the final AAB."
}

$OldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $JarOutput = @(& jarsigner -verify "$OutputAab" 2>&1)
    $JarExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $OldPreference
}

if ($JarExit -ne 0) {
    $JarOutput | ForEach-Object { Write-Host $_ }
    Fail "AAB JAR signature integrity verification failed."
}

$OldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $CertOutput = @(& keytool -printcert -jarfile "$OutputAab" 2>&1)
    $CertExit = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $OldPreference
}

if ($CertExit -ne 0) {
    Fail "Unable to inspect AAB signer certificate."
}

$ShaLine = $CertOutput |
    Where-Object { ([string]$_) -match 'SHA-?256:' } |
    Select-Object -First 1

if (-not $ShaLine) {
    Fail "AAB signer SHA-256 was not found."
}

$ActualSha256 = (([string]$ShaLine -split ":", 2)[1] -replace '[^0-9A-Fa-f]', '').ToUpperInvariant()

if ($ActualSha256 -ne $ExpectedUploadSha256) {
    Fail "Wrong AAB signer certificate."
}

$AabHash = (Get-FileHash -LiteralPath $OutputAab -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "[ OK ] Play AAB built from existing base module and verified." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host "AAB: $OutputAab" -ForegroundColor Cyan
Write-Host "AAB file SHA-256: $AabHash" -ForegroundColor Cyan
Write-Host "Upload signer SHA-256: $ActualSha256" -ForegroundColor Cyan