[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$FirebaseServiceAccountJsonPath,
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedFirebaseProjectId = "dalilalhami-504320"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $root = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $credentialPath = (Resolve-Path -LiteralPath `
        $FirebaseServiceAccountJsonPath).Path
    $migrationName = `
        "20260807193000_notification_center_admin_send.sql"
    $migrationPath = Join-Path $root "supabase\migrations\$migrationName"
    $functionName = "admin-notifications"
    $functionPath = Join-Path $root `
        "supabase\functions\$functionName\index.ts"
    $linkedRefPath = Join-Path $root "supabase\.temp\project-ref"

    foreach ($path in @(
        $migrationPath,
        $functionPath,
        $linkedRefPath,
        $credentialPath
    )) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required Phase 10B file is missing: $path"
        }
    }

    $projectRef = (Get-Content -LiteralPath $linkedRefPath `
        -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($projectRef)) {
        throw "The linked Supabase project reference is empty."
    }

    $credential = Get-Content -LiteralPath $credentialPath `
        -Raw -Encoding UTF8 | ConvertFrom-Json
    $credentialProjectId = [string]$credential.project_id
    $credentialType = [string]$credential.type
    $credentialEmail = [string]$credential.client_email
    $credentialPrivateKey = [string]$credential.private_key

    if ($credentialType -ne "service_account") {
        throw "The Firebase credential JSON is not a service-account key."
    }
    if ($credentialProjectId -ne $ExpectedFirebaseProjectId) {
        throw (
            "Firebase credential project mismatch. Expected " +
            "$ExpectedFirebaseProjectId but found $credentialProjectId."
        )
    }
    if ([string]::IsNullOrWhiteSpace($credentialEmail) -or
        [string]::IsNullOrWhiteSpace($credentialPrivateKey)) {
        throw "The Firebase service-account JSON is incomplete."
    }

    $compactJson = $credential | ConvertTo-Json -Depth 20 -Compress
    $tempEnvPath = Join-Path $env:TEMP (
        "dalil_phase10b_firebase_secret_" +
        [Guid]::NewGuid().ToString("N") +
        ".env"
    )
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText(
        $tempEnvPath,
        "FIREBASE_SERVICE_ACCOUNT_JSON=$compactJson",
        $utf8NoBom
    )

    try {
        Push-Location $root
        try {
            Write-Host ""
            Write-Host "==> Storing Firebase credential in Supabase secrets" `
                -ForegroundColor Cyan
            & npx.cmd --yes supabase@latest secrets set `
                --env-file $tempEnvPath `
                --project-ref $projectRef
            if ($LASTEXITCODE -ne 0) {
                throw (
                    "Supabase secrets set failed with exit code " +
                    "$LASTEXITCODE."
                )
            }

            Write-Host ""
            Write-Host "==> Applying Phase 10B Supabase migration" `
                -ForegroundColor Cyan
            Write-Host (
                "Confirm the migration when Supabase asks to apply " +
                $migrationName + "."
            ) -ForegroundColor Yellow
            & npx.cmd --yes supabase@latest db push --linked
            if ($LASTEXITCODE -ne 0) {
                throw "Supabase db push failed with exit code $LASTEXITCODE."
            }

            Write-Host ""
            Write-Host "==> Deploying admin-notifications Edge Function" `
                -ForegroundColor Cyan
            & npx.cmd --yes supabase@latest functions deploy `
                $functionName `
                --project-ref $projectRef `
                --use-api
            if ($LASTEXITCODE -ne 0) {
                throw (
                    "Supabase function deploy failed with exit code " +
                    "$LASTEXITCODE."
                )
            }
        }
        finally {
            Pop-Location
        }
    }
    finally {
        Remove-Item -LiteralPath $tempEnvPath `
            -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[ OK ] Firebase credential stored as a server secret." `
        -ForegroundColor Green
    Write-Host "[ OK ] Phase 10B migration was pushed." `
        -ForegroundColor Green
    Write-Host "[ OK ] admin-notifications Edge Function was deployed." `
        -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
