[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",

    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = "$env:USERPROFILE\Desktop"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Invoke-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    $output = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        $details = ($output | Out-String).Trim()
        throw "$FailureMessage`n$details"
    }

    return @($output)
}

try {
    Write-Step "Checking Flutter project and Git repository"

    $resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $pubspecPath = Join-Path $resolvedProjectRoot "pubspec.yaml"

    if (-not (Test-Path -LiteralPath $pubspecPath -PathType Leaf)) {
        throw "pubspec.yaml was not found in: $resolvedProjectRoot"
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git was not found in PATH."
    }

    New-Item -ItemType Directory `
        -Path $OutputDirectory `
        -Force | Out-Null

    Push-Location $resolvedProjectRoot
    try {
        $insideRepository = (
            Invoke-GitText `
                -Arguments @("rev-parse", "--is-inside-work-tree") `
                -FailureMessage "The project is not a Git repository."
        )[0].Trim()

        if ($insideRepository -ne "true") {
            throw "The project is not inside a Git work tree."
        }

        Write-Step "Checking that the latest phase is committed"

        $statusLines = @(
            Invoke-GitText `
                -Arguments @("status", "--porcelain") `
                -FailureMessage "Unable to read Git status."
        )

        if ($statusLines.Count -gt 0) {
            Write-Host ""
            Write-Host "Uncommitted or untracked files were found:" `
                -ForegroundColor Yellow
            $statusLines | ForEach-Object {
                Write-Host $_ -ForegroundColor Yellow
            }

            throw (
                "The repository is not clean. Commit the current changes " +
                "before exporting so the ZIP includes the exact latest version."
            )
        }

        Write-Ok "Git working tree is clean."

        $shortCommit = (
            Invoke-GitText `
                -Arguments @("rev-parse", "--short=10", "HEAD") `
                -FailureMessage "Unable to determine the current commit."
        )[0].Trim()

        $branch = (
            Invoke-GitText `
                -Arguments @("branch", "--show-current") `
                -FailureMessage "Unable to determine the current branch."
        )[0].Trim()

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = (
            "DalilAlHami_Current_Source_" +
            $timestamp +
            "_" +
            $shortCommit +
            ".zip"
        )
        $outputPath = Join-Path $OutputDirectory $fileName

        if (Test-Path -LiteralPath $outputPath) {
            Remove-Item -LiteralPath $outputPath -Force
        }

        Write-Step "Creating compact source ZIP from Git HEAD"

        & git archive `
            --format=zip `
            --output="$outputPath" `
            HEAD

        if ($LASTEXITCODE -ne 0) {
            throw "git archive failed with exit code $LASTEXITCODE."
        }

        if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw "The source ZIP was not created."
        }

        Write-Step "Verifying ZIP integrity"

        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $archive = [IO.Compression.ZipFile]::OpenRead($outputPath)
        try {
            if ($archive.Entries.Count -eq 0) {
                throw "The generated ZIP is empty."
            }

            $entryCount = $archive.Entries.Count
        }
        finally {
            $archive.Dispose()
        }

        $file = Get-Item -LiteralPath $outputPath
        $sizeMb = [Math]::Round($file.Length / 1MB, 2)
        $hash = (Get-FileHash `
            -LiteralPath $outputPath `
            -Algorithm SHA256).Hash

        $reportPath = "$outputPath.info.txt"

        @(
            "Dalil Al Hami compact Flutter source export"
            "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            "Project: $resolvedProjectRoot"
            "Branch: $branch"
            "Commit: $shortCommit"
            "ZIP entries: $entryCount"
            "Size MB: $sizeMb"
            "SHA256: $hash"
            ""
            "This archive contains files tracked by Git at HEAD."
            "It does not contain .git, build caches, APKs, logs, or untracked secrets."
        ) | Set-Content `
            -LiteralPath $reportPath `
            -Encoding UTF8

        Write-Host ""
        Write-Host "======================================================" `
            -ForegroundColor DarkCyan
        Write-Host "Compact Flutter source export completed." `
            -ForegroundColor Green
        Write-Host "ZIP: $outputPath" -ForegroundColor White
        Write-Host "Size: $sizeMb MB" -ForegroundColor White
        Write-Host "Files: $entryCount" -ForegroundColor White
        Write-Host "SHA256: $hash" -ForegroundColor White
        Write-Host "Report: $reportPath" -ForegroundColor White
        Write-Host "======================================================" `
            -ForegroundColor DarkCyan

        if ($file.Length -gt 500MB) {
            Write-Host ""
            Write-Host (
                "[WARN] The compact ZIP still exceeds 500 MB. " +
                "This means very large binary files are tracked by Git."
            ) -ForegroundColor Yellow
        }
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
