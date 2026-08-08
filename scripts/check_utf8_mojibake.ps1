[CmdletBinding()]
param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false, $true)

$targets = @(
    "pubspec.yaml",
    "test\phase12b11_developer_update_checker_test.dart"
)

$badTokens = @(
    ([string][char]0x00A7), # section sign, common in Arabic mojibake sequences
    ([string][char]0x201E)  # low double quote, another common mojibake artifact
)

$failed = $false

foreach ($relative in $targets) {
    $path = Join-Path $ProjectRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "[ERROR] Missing: $relative" -ForegroundColor Red
        $failed = $true
        continue
    }

    try {
        $text = [System.IO.File]::ReadAllText($path, $Utf8NoBom)
    }
    catch {
        Write-Host "[ERROR] Invalid UTF-8: $relative" -ForegroundColor Red
        $failed = $true
        continue
    }

    foreach ($token in $badTokens) {
        if ($text.Contains($token)) {
            Write-Host "[ERROR] Possible mojibake detected in: $relative" -ForegroundColor Red
            $failed = $true
            break
        }
    }

    if (-not $failed) {
        Write-Host "[ OK ] UTF-8 clean: $relative" -ForegroundColor Green
    }
}

if ($failed) {
    exit 1
}

Write-Host "[ OK ] UTF-8 / mojibake guard passed." -ForegroundColor Green
