[CmdletBinding()]
param(
    [string]$ProjectName = "dalilalhami-share",
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",
    [string]$SupabaseUrl = $env:SUPABASE_URL,
    [string]$SupabasePublishableKey = $env:SUPABASE_PUBLISHABLE_KEY,
    [switch]$SkipSupabasePreview,
    [switch]$ConfirmDeploy
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$WranglerPackage = "wrangler@4.125.0"

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Assert-LastExitCode([string]$Message) {
    if ($LASTEXITCODE -ne 0) {
        throw "$Message Exit code: $LASTEXITCODE"
    }
}

function Test-CloudflareAuthentication {
    $AuthOutput = $null
    $AuthInfo = $null
    try {
        $AuthOutput = @(
            & npx --yes $WranglerPackage auth token --json 2>$null
        )
        $AuthExitCode = $LASTEXITCODE
        if ($AuthExitCode -ne 0 -or $AuthOutput.Count -eq 0) {
            return $false
        }

        $AuthInfo = ($AuthOutput -join "`n") | ConvertFrom-Json
        if ($null -eq $AuthInfo) {
            return $false
        }

        $AuthType = [string]$AuthInfo.type
        $AuthToken = [string]$AuthInfo.token
        return (-not [string]::IsNullOrWhiteSpace($AuthType) -and
            -not [string]::IsNullOrWhiteSpace($AuthToken))
    } catch {
        return $false
    } finally {
        $AuthOutput = $null
        $AuthInfo = $null
    }
}

if (-not $ConfirmDeploy) {
    throw "Cloudflare deployment was not confirmed. Add -ConfirmDeploy after reviewing the files."
}
if ($ProjectName -ne "dalilalhami-share") {
    throw "The Android App Link is fixed to dalilalhami-share.pages.dev. Do not change ProjectName."
}
if (-not (Get-Command "npx" -ErrorAction SilentlyContinue)) {
    throw "npx was not found. Install the current Node.js LTS release first."
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$LocalSupabaseConfig = Join-Path $ProjectRoot ".supabase.local.ps1"
if (([string]::IsNullOrWhiteSpace($SupabaseUrl) -or
     [string]::IsNullOrWhiteSpace($SupabasePublishableKey)) -and
    (Test-Path -LiteralPath $LocalSupabaseConfig -PathType Leaf)) {
    . $LocalSupabaseConfig
}

$SiteRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$PublicRoot = Join-Path $SiteRoot "public"
$FunctionsRoot = Join-Path $SiteRoot "functions"
$AssetLinksPath = Join-Path $PublicRoot ".well-known\assetlinks.json"
foreach ($RequiredPath in @($PublicRoot, $FunctionsRoot, $AssetLinksPath)) {
    if (-not (Test-Path -LiteralPath $RequiredPath)) {
        throw "Required share-site file is missing: $RequiredPath"
    }
}

Set-Location $SiteRoot

Write-Step "Checking Cloudflare Wrangler login"
if (-not (Test-CloudflareAuthentication)) {
    Write-Host "Cloudflare is not authenticated." -ForegroundColor Yellow
    Write-Host "A secure device login will start now. Approve it in the browser, then return to this terminal." -ForegroundColor Yellow

    Write-Step "Starting Cloudflare device login"
    & npx --yes $WranglerPackage login --device
    Assert-LastExitCode "Cloudflare device login failed."

    if (-not (Test-CloudflareAuthentication)) {
        throw "Cloudflare login did not create a usable OAuth session. Run: npx --yes $WranglerPackage login --device"
    }
}
Write-Ok "Cloudflare account is available."

Write-Step "Checking the dedicated Pages project"
$ProjectJson = @(
    & npx --yes $WranglerPackage pages project list --json 2>$null
)
$ProjectListExitCode = $LASTEXITCODE
if ($ProjectListExitCode -ne 0) {
    throw "Unable to list Cloudflare Pages projects. Verify that the authenticated account has Pages Read and Pages Write access. Exit code: $ProjectListExitCode"
}

try {
    $ProjectDocument = ($ProjectJson -join "`n") | ConvertFrom-Json
} catch {
    throw "Cloudflare returned an unreadable Pages project list. No deployment was attempted."
}

$Projects = @()
if ($ProjectDocument -is [System.Array]) {
    $Projects = @($ProjectDocument)
} elseif ($ProjectDocument.PSObject.Properties.Name -contains "result") {
    $Projects = @($ProjectDocument.result)
} else {
    $Projects = @($ProjectDocument)
}

$ProjectExists = $false
foreach ($Project in $Projects) {
    if ($null -ne $Project -and
        $Project.PSObject.Properties.Name -contains "name" -and
        [string]$Project.name -eq $ProjectName) {
        $ProjectExists = $true
        break
    }
}
if (-not $ProjectExists) {
    & npx --yes $WranglerPackage pages project create $ProjectName `
        --production-branch master
    Assert-LastExitCode "Unable to create the Cloudflare Pages project."
    Write-Ok "Cloudflare Pages project created: $ProjectName"
} else {
    Write-Ok "Existing Cloudflare Pages project found: $ProjectName"
}

if (-not $SkipSupabasePreview) {
    if ([string]::IsNullOrWhiteSpace($SupabaseUrl) -or
        [string]::IsNullOrWhiteSpace($SupabasePublishableKey)) {
        throw "SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required for rich business previews. Pass both parameters or use -SkipSupabasePreview."
    }

    Write-Step "Saving read-only Supabase preview settings in Cloudflare"
    $SupabaseUrl.Trim() |
        & npx --yes $WranglerPackage pages secret put SUPABASE_URL `
            --project-name $ProjectName
    Assert-LastExitCode "Unable to save SUPABASE_URL in Cloudflare."

    $SupabasePublishableKey.Trim() |
        & npx --yes $WranglerPackage pages secret put `
            SUPABASE_PUBLISHABLE_KEY --project-name $ProjectName
    Assert-LastExitCode "Unable to save SUPABASE_PUBLISHABLE_KEY in Cloudflare."
    Write-Ok "Rich-preview settings saved without writing them to source files."
}

Write-Step "Deploying the public share site and Pages Function"
& npx --yes $WranglerPackage pages deploy $PublicRoot `
    --project-name $ProjectName `
    --branch master `
    --commit-dirty=true
Assert-LastExitCode "Cloudflare Pages deployment failed."
Write-Ok "Share site deployed."

$SiteUrl = "https://$ProjectName.pages.dev"
$ExpectedFingerprint = `
    "5B:63:0A:18:CD:75:E7:A8:6D:53:0F:5F:FE:55:01:FE:" + `
    "B2:45:3B:76:13:7E:A5:DF:FF:37:15:08:07:96:91:24"

Write-Step "Verifying the public App Links association"
$Verified = $false
for ($Attempt = 1; $Attempt -le 6; $Attempt++) {
    try {
        $Response = Invoke-WebRequest `
            -Uri "$SiteUrl/.well-known/assetlinks.json" `
            -UseBasicParsing `
            -TimeoutSec 20
        if ($Response.StatusCode -eq 200 -and
            $Response.Content.Contains($ExpectedFingerprint)) {
            $Verified = $true
            break
        }
    } catch {
        if ($Attempt -eq 6) {
            throw
        }
    }
    Start-Sleep -Seconds 3
}
if (-not $Verified) {
    throw "Cloudflare deployed, but assetlinks.json verification failed."
}
Write-Ok "Android production signing association is public and correct."

Write-Step "Verifying the dynamic business landing route"
$LandingResponse = Invoke-WebRequest `
    -Uri "$SiteUrl/b/phase18a-check" `
    -UseBasicParsing `
    -TimeoutSec 20
if ($LandingResponse.StatusCode -ne 200 -or
    -not $LandingResponse.Content.Contains('business-card') -or
    -not $LandingResponse.Content.Contains('DalilAlHami.apk')) {
    throw "Cloudflare deployed, but the business landing Function verification failed."
}
Write-Ok "Dynamic business landing route is public and working."

Write-Host "`n======================================================" -ForegroundColor Green
Write-Host "DalilAlHami business share site deployed successfully." -ForegroundColor Green
Write-Host "Site: $SiteUrl" -ForegroundColor Cyan
Write-Host "App Links: $SiteUrl/b/<business-id>" -ForegroundColor Cyan
Write-Host "No Supabase table, row, image, or storage object was created." -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
