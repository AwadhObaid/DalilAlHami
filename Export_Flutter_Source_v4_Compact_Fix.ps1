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

function Write-WarnMessage {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Invoke-GitLines {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    $rawOutput = @(& git @Arguments 2>&1)
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $details = ($rawOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($details)) {
            $details = "Git exited with code $exitCode."
        }

        throw "$FailureMessage`n$details"
    }

    return ,$rawOutput
}

function Invoke-GitScalar {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    $lines = @(
        Invoke-GitLines `
            -Arguments $Arguments `
            -FailureMessage $FailureMessage
    )

    $value = ($lines | Out-String).Trim()

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$FailureMessage`nGit returned an empty result."
    }

    return [string]$value
}

function Test-GitQuiet {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    & git @Arguments *> $null
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        return $true
    }

    if ($exitCode -eq 1) {
        return $false
    }

    throw "$FailureMessage Git exited with code $exitCode."
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
        $insideRepository = Invoke-GitScalar `
            -Arguments @("rev-parse", "--is-inside-work-tree") `
            -FailureMessage "The project is not a Git repository."

        if ($insideRepository -ne "true") {
            throw "The project is not inside a Git work tree."
        }

        Write-Step "Checking committed project state"

        $workingTreeClean = Test-GitQuiet `
            -Arguments @("diff", "--quiet", "--ignore-submodules", "--") `
            -FailureMessage "Unable to inspect working-tree changes."

        $indexClean = Test-GitQuiet `
            -Arguments @(
                "diff",
                "--cached",
                "--quiet",
                "--ignore-submodules",
                "--"
            ) `
            -FailureMessage "Unable to inspect staged changes."

        if (-not $workingTreeClean -or -not $indexClean) {
            $trackedChanges = @(
                Invoke-GitLines `
                    -Arguments @(
                        "status",
                        "--short",
                        "--untracked-files=no"
                    ) `
                    -FailureMessage "Unable to list tracked changes."
            )

            Write-Host ""
            Write-Host "Tracked changes not included in HEAD:" `
                -ForegroundColor Yellow

            foreach ($line in $trackedChanges) {
                Write-Host $line -ForegroundColor Yellow
            }

            throw (
                "Commit or discard the tracked changes before exporting. " +
                "The ZIP is intentionally created from the exact Git HEAD."
            )
        }

        Write-Ok "All tracked project changes are committed."

        $untrackedFiles = @(
            Invoke-GitLines `
                -Arguments @(
                    "ls-files",
                    "--others",
                    "--exclude-standard"
                ) `
                -FailureMessage "Unable to inspect untracked files."
        )

        if ($untrackedFiles.Count -gt 0) {
            $importantUntracked = @(
                $untrackedFiles | Where-Object {
                    $_ -match (
                        "^(lib|test|android|ios|assets|supabase|scripts)/" +
                        "|^pubspec\.ya?ml$"
                    )
                }
            )

            if ($importantUntracked.Count -gt 0) {
                Write-Host ""
                Write-Host (
                    "Important untracked project files were found and " +
                    "would not be included:"
                ) -ForegroundColor Yellow

                foreach ($line in $importantUntracked) {
                    Write-Host $line -ForegroundColor Yellow
                }

                throw (
                    "Add and commit these source files before exporting."
                )
            }

            Write-WarnMessage (
                "Non-source untracked files were found and will be ignored. " +
                "This is safe because the export uses Git HEAD."
            )
        }

        $shortCommit = Invoke-GitScalar `
            -Arguments @("rev-parse", "--short=10", "HEAD") `
            -FailureMessage "Unable to determine the current commit."

        $fullCommit = Invoke-GitScalar `
            -Arguments @("rev-parse", "HEAD") `
            -FailureMessage "Unable to determine the full commit."

        $branch = Invoke-GitScalar `
            -Arguments @("branch", "--show-current") `
            -FailureMessage "Unable to determine the current branch."

        $tagLines = @(
            Invoke-GitLines `
                -Arguments @(
                    "tag",
                    "--points-at",
                    "HEAD"
                ) `
                -FailureMessage "Unable to read tags at HEAD."
        )

        $tags = ($tagLines | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_)
        }) -join ", "

        if ([string]::IsNullOrWhiteSpace($tags)) {
            $tags = "(no tag at HEAD)"
        }

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
        $hash = (
            Get-FileHash `
                -LiteralPath $outputPath `
                -Algorithm SHA256
        ).Hash

        $reportPath = "$outputPath.info.txt"

        @(
            "Dalil Al Hami compact Flutter source export"
            "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            "Project: $resolvedProjectRoot"
            "Branch: $branch"
            "Tags at HEAD: $tags"
            "Commit: $fullCommit"
            "ZIP entries: $entryCount"
            "Size MB: $sizeMb"
            "SHA256: $hash"
            ""
            "The archive contains files tracked by Git at HEAD."
            "It excludes .git, build caches, APKs, logs, and untracked secrets."
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
        Write-Host "Branch: $branch" -ForegroundColor White
        Write-Host "Tags: $tags" -ForegroundColor White
        Write-Host "Commit: $shortCommit" -ForegroundColor White
        Write-Host "SHA256: $hash" -ForegroundColor White
        Write-Host "Report: $reportPath" -ForegroundColor White
        Write-Host "======================================================" `
            -ForegroundColor DarkCyan

        if ($file.Length -gt 500MB) {
            Write-Host ""
            Write-WarnMessage (
                "The compact ZIP still exceeds 500 MB. Large binary files " +
                "are likely committed to Git and must be reviewed."
            )
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
