[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = "F:\FlutterProjects\DalilAlHami_Clean",

    [ValidateSet("Recommended", "Emergency")]
    [string]$Mode = "Recommended",

    [ValidateRange(0, 12288)]
    [int]$HeapMb = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Ok {
    param([Parameter(Mandatory)][string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Get-PhysicalMemoryMb {
    try {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem
        $bytes = [int64]$computer.TotalPhysicalMemory
        if ($bytes -gt 0) {
            return [int][Math]::Floor($bytes / 1MB)
        }
    }
    catch {
    }

    return 8192
}

function Get-AdaptiveHeapMb {
    param(
        [Parameter(Mandatory)][int]$PhysicalMemoryMb,
        [Parameter(Mandatory)][string]$BuildMode
    )

    if ($BuildMode -eq "Emergency") {
        if ($PhysicalMemoryMb -ge 24576) { return 12288 }
        if ($PhysicalMemoryMb -ge 16384) { return 10240 }
        if ($PhysicalMemoryMb -ge 12288) { return 8192 }
        if ($PhysicalMemoryMb -ge 8192) { return 6144 }
        return 4096
    }

    if ($PhysicalMemoryMb -ge 24576) { return 8192 }
    if ($PhysicalMemoryMb -ge 16384) { return 6144 }
    if ($PhysicalMemoryMb -ge 12288) { return 5120 }
    if ($PhysicalMemoryMb -ge 8192) { return 5120 }
    return 4096
}

function Get-ExistingHeapMb {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return 0
    }

    $source = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match(
        $source,
        "(?im)^org\.gradle\.jvmargs=.*?-Xmx(\d+)([gGmM])"
    )
    if (-not $match.Success) {
        return 0
    }

    $value = [int]$match.Groups[1].Value
    $unit = $match.Groups[2].Value.ToLowerInvariant()
    if ($unit -eq "g") {
        return $value * 1024
    }

    return $value
}

function Set-GradleProperties {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Properties
    )

    $lines = @()
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $lines = @(Get-Content -LiteralPath $Path)
    }

    $written = @{}
    $result = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        $matchedKey = $null
        foreach ($key in $Properties.Keys) {
            $pattern = "^\s*" + [regex]::Escape($key) + "\s*="
            if ($line -match $pattern) {
                $matchedKey = $key
                break
            }
        }

        if ($null -eq $matchedKey) {
            $result.Add([string]$line)
            continue
        }

        if (-not $written.ContainsKey($matchedKey)) {
            $result.Add("$matchedKey=$($Properties[$matchedKey])")
            $written[$matchedKey] = $true
        }
    }

    foreach ($key in $Properties.Keys) {
        if (-not $written.ContainsKey($key)) {
            $result.Add("$key=$($Properties[$key])")
        }
    }

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllLines($Path, $result, $encoding)
}

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $gradlePropertiesPath = Join-Path $resolvedRoot "android\gradle.properties"
    $physicalMemoryMb = Get-PhysicalMemoryMb

    $selectedHeapMb = $HeapMb
    if ($selectedHeapMb -le 0) {
        $selectedHeapMb = Get-AdaptiveHeapMb `
            -PhysicalMemoryMb $physicalMemoryMb `
            -BuildMode $Mode
    }

    $existingHeapMb = Get-ExistingHeapMb -Path $gradlePropertiesPath
    if ($existingHeapMb -gt $selectedHeapMb) {
        $selectedHeapMb = $existingHeapMb
    }

    $properties = [ordered]@{
        "org.gradle.jvmargs" = (
            "-Xms512m -Xmx${selectedHeapMb}m " +
            "-XX:MaxMetaspaceSize=1536m " +
            "-XX:ReservedCodeCacheSize=512m " +
            "-XX:+HeapDumpOnOutOfMemoryError " +
            "-Dfile.encoding=UTF-8"
        )
        "org.gradle.workers.max" = "1"
        "org.gradle.parallel" = "false"
        "org.gradle.daemon" = "false"
        "org.gradle.vfs.watch" = "false"
        "kotlin.compiler.execution.strategy" = "in-process"
    }

    Set-GradleProperties `
        -Path $gradlePropertiesPath `
        -Properties $properties

    $stateDirectory = Join-Path $resolvedRoot "build_logs"
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    $statePath = Join-Path $stateDirectory `
        "phase08b_gradle_memory_settings.txt"

    @(
        "mode=$Mode"
        "physical_memory_mb=$physicalMemoryMb"
        "heap_mb=$selectedHeapMb"
        "gradle_properties=$gradlePropertiesPath"
    ) | Set-Content -LiteralPath $statePath -Encoding ASCII

    Write-Ok "Gradle heap: ${selectedHeapMb} MB ($Mode mode)"
    Write-Ok "Gradle workers: 1; parallel execution: disabled"
    Write-Ok "Gradle properties: $gradlePropertiesPath"
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
