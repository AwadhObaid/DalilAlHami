<#
.SYNOPSIS
    إنشاء نسخة ZIP آمنة من سورس مشروع Flutter لرفعها للفحص أو النقل.

.DESCRIPTION
    النسخة v2 تتجنب الدخول إلى مجلدات Flutter المؤقتة والروابط الرمزية،
    مثل windows\flutter\ephemeral\.plugin_symlinks، وتنسخ فقط ملفات السورس الفعلية.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File ".\Export_Flutter_Source_v2.ps1" `
      -ProjectRoot "F:\FlutterProjects\DalilAlHami"

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File ".\Export_Flutter_Source_v2.ps1" `
      -ProjectRoot "F:\FlutterProjects\DalilAlHami" `
      -IncludeFirebaseClientConfig
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectRoot = (Get-Location).Path,

    [ValidateNotNullOrEmpty()]
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE "Desktop\Flutter_Source_Exports"),

    [switch]$IncludeFirebaseClientConfig,

    [switch]$KeepStagingFolder
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[ OK ] $Message" -ForegroundColor Green
}

function Write-WarnMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Remove-PathSafely {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    }
}

function Get-SafeProjectName {
    param([Parameter(Mandatory)][string]$Name)

    $safeName = $Name
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safeName = $safeName.Replace([string]$char, "_")
    }

    $safeName = $safeName.Trim()
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        return "FlutterProject"
    }

    return $safeName
}

function Get-RelativePathSafe {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$FullPath
    )

    return $FullPath.Substring($BasePath.Length).TrimStart('\', '/')
}

function Test-ReparsePoint {
    param([Parameter(Mandatory)][System.IO.FileSystemInfo]$Item)

    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Test-ExcludedDirectory {
    param(
        [Parameter(Mandatory)][System.IO.DirectoryInfo]$Directory,
        [Parameter(Mandatory)][string]$RelativePath
    )

    $excludedDirectoryNames = @(
        ".dart_tool",
        ".git",
        ".gradle",
        ".idea",
        ".pub-cache",
        ".symlinks",
        ".plugin_symlinks",
        ".vscode-test",
        "build",
        "coverage",
        "DerivedData",
        "Pods",
        "node_modules",
        "xcuserdata",
        "ephemeral"
    )

    if ($excludedDirectoryNames -contains $Directory.Name) {
        return $true
    }

    # استبعادات إضافية لمسارات Flutter المولدة في منصات سطح المكتب.
    $normalized = $RelativePath.Replace('/', '\').ToLowerInvariant()
    $generatedPathFragments = @(
        "\flutter\ephemeral",
        "\generated\",
        "\cmake-build-",
        "\runner\debug",
        "\runner\release"
    )

    foreach ($fragment in $generatedPathFragments) {
        if ($normalized.Contains($fragment)) {
            return $true
        }
    }

    return $false
}

function Test-SensitiveFile {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$File,
        [Parameter(Mandatory)][bool]$AllowFirebaseClientConfig
    )

    $name = $File.Name
    $lowerName = $name.ToLowerInvariant()

    if ($lowerName -eq "google-services.json" -or
        $lowerName -eq "googleservice-info.plist") {
        return (-not $AllowFirebaseClientConfig)
    }

    $exactSensitiveNames = @(
        "key.properties",
        "local.properties",
        ".env",
        ".env.local",
        ".env.production",
        ".env.development",
        ".env.staging",
        "service-account.json",
        "service_account.json",
        "firebase-service-account.json",
        "firebase_service_account.json",
        "credentials.json",
        "secrets.json"
    )

    if ($exactSensitiveNames -contains $lowerName) {
        return $true
    }

    $sensitivePatterns = @(
        "*.jks",
        "*.keystore",
        "*.p12",
        "*.pfx",
        "*.pem",
        "*.key",
        "*.mobileprovision",
        "firebase-adminsdk-*.json",
        "*service-account*.json",
        "*service_account*.json",
        "*credentials*.json",
        "*secret*.json"
    )

    foreach ($pattern in $sensitivePatterns) {
        if ($name -like $pattern) {
            return $true
        }
    }

    return $false
}

function Test-UnneededFile {
    param([Parameter(Mandatory)][System.IO.FileInfo]$File)

    $exactGeneratedNames = @(
        ".flutter-plugins",
        ".packages",
        "Generated.xcconfig",
        "flutter_export_environment.sh"
    )

    if ($exactGeneratedNames -contains $File.Name) {
        return $true
    }

    $unneededPatterns = @(
        "*.apk",
        "*.aab",
        "*.ipa",
        "*.app",
        "*.exe",
        "*.msi",
        "*.dmg",
        "*.iso",
        "*.zip",
        "*.7z",
        "*.rar",
        "*.tar",
        "*.gz",
        "*.log",
        "*.tmp",
        "*.temp",
        "*.bak",
        "*.class",
        "*.dex",
        "*.o",
        "*.obj",
        "*.so",
        "*.dll",
        "*.dylib",
        "*.xcarchive"
    )

    foreach ($pattern in $unneededPatterns) {
        if ($File.Name -like $pattern) {
            return $true
        }
    }

    return $false
}

try {
    Write-Step "التحقق من مسار المشروع"

    $resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path.TrimEnd('\', '/')
    $pubspecPath = Join-Path $resolvedProjectRoot "pubspec.yaml"

    if (-not (Test-Path -LiteralPath $pubspecPath -PathType Leaf)) {
        throw "لم يتم العثور على pubspec.yaml. المسار المحدد لا يبدو مشروع Flutter: $resolvedProjectRoot"
    }

    $projectDirectoryInfo = Get-Item -LiteralPath $resolvedProjectRoot
    $projectName = Get-SafeProjectName -Name $projectDirectoryInfo.Name
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $resolvedOutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path

    $archiveBaseName = "${projectName}_Flutter_Source_${timestamp}"
    $zipPath = Join-Path $resolvedOutputDirectory "${archiveBaseName}.zip"

    # اسم قصير للمجلد المؤقت لتجنب مشكلات طول المسار في Windows PowerShell 5.1.
    $stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) "FSE_$timestamp"
    $stagingProject = Join-Path $stagingRoot $projectName

    Remove-PathSafely -Path $stagingRoot
    New-Item -ItemType Directory -Path $stagingProject -Force | Out-Null

    Write-Ok "المشروع: $resolvedProjectRoot"
    Write-Ok "مجلد الإخراج: $resolvedOutputDirectory"

    Write-Step "نسخ ملفات السورس المطلوبة"

    $excludedItems = New-Object System.Collections.Generic.List[string]
    $copiedFiles = New-Object System.Collections.Generic.List[string]
    $copyWarnings = New-Object System.Collections.Generic.List[string]

    # نستخدم Stack بدل Get-ChildItem -Recurse حتى لا ندخل إلى الروابط الرمزية أصلًا.
    $directoriesToProcess = New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]
    $directoriesToProcess.Push($projectDirectoryInfo)

    while ($directoriesToProcess.Count -gt 0) {
        $currentDirectory = $directoriesToProcess.Pop()

        try {
            $children = Get-ChildItem -LiteralPath $currentDirectory.FullName -Force -ErrorAction Stop
        }
        catch {
            $relativeCurrent = Get-RelativePathSafe -BasePath $resolvedProjectRoot -FullPath $currentDirectory.FullName
            $copyWarnings.Add("$relativeCurrent`t[تعذر قراءة المجلد: $($_.Exception.Message)]")
            continue
        }

        foreach ($item in $children) {
            $relativePath = Get-RelativePathSafe -BasePath $resolvedProjectRoot -FullPath $item.FullName

            if ($item.PSIsContainer) {
                if (Test-ReparsePoint -Item $item) {
                    $excludedItems.Add("$relativePath`t[رابط رمزي/نقطة إعادة تحليل]")
                    continue
                }

                if (Test-ExcludedDirectory -Directory $item -RelativePath $relativePath) {
                    $excludedItems.Add("$relativePath`t[مجلد مولد أو غير مطلوب]")
                    continue
                }

                $directoriesToProcess.Push([System.IO.DirectoryInfo]$item)
                continue
            }

            if (Test-ReparsePoint -Item $item) {
                $excludedItems.Add("$relativePath`t[ملف رابط رمزي]")
                continue
            }

            $file = [System.IO.FileInfo]$item

            if (Test-SensitiveFile -File $file -AllowFirebaseClientConfig $IncludeFirebaseClientConfig.IsPresent) {
                $excludedItems.Add("$relativePath`t[ملف حساس]")
                continue
            }

            if (Test-UnneededFile -File $file) {
                $excludedItems.Add("$relativePath`t[ملف مولد/ثنائي غير مطلوب]")
                continue
            }

            $destinationPath = Join-Path $stagingProject $relativePath
            $destinationDirectory = Split-Path -Parent $destinationPath

            try {
                if (-not (Test-Path -LiteralPath $destinationDirectory)) {
                    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
                }

                Copy-Item -LiteralPath $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                $copiedFiles.Add($relativePath)
            }
            catch {
                # لا نوقف العملية بسبب ملف مؤقت اختفى أثناء النسخ.
                $copyWarnings.Add("$relativePath`t[تعذر النسخ: $($_.Exception.Message)]")
            }
        }
    }

    if ($copiedFiles.Count -eq 0) {
        throw "لم يتم نسخ أي ملفات من المشروع."
    }

    Write-Ok "تم نسخ $($copiedFiles.Count) ملفًا"
    Write-WarnMessage "تم استبعاد $($excludedItems.Count) عنصرًا غير مطلوب أو حساسًا"

    if ($copyWarnings.Count -gt 0) {
        Write-WarnMessage "تم تجاوز $($copyWarnings.Count) ملفًا/مجلدًا تعذر الوصول إليه، وستجد التفاصيل في التقرير"
    }

    Write-Step "إنشاء تقرير النسخة"

    $reportPath = Join-Path $stagingProject "SOURCE_EXPORT_REPORT.txt"
    $fileListPath = Join-Path $stagingProject "SOURCE_FILE_LIST.txt"
    $excludedListPath = Join-Path $stagingProject "EXCLUDED_FILE_LIST.txt"
    $warningsListPath = Join-Path $stagingProject "COPY_WARNINGS.txt"

    $flutterVersion = "غير متاح"
    try {
        $flutterCommand = Get-Command flutter -ErrorAction Stop
        $flutterVersionOutput = & $flutterCommand.Source --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $flutterVersionOutput) {
            $flutterVersion = ($flutterVersionOutput | Select-Object -First 1)
        }
    }
    catch {
        $flutterVersion = "Flutter غير موجود في PATH على هذا الجهاز"
    }

    $firebaseConfigIncluded = if ($IncludeFirebaseClientConfig.IsPresent) { "نعم" } else { "لا" }

    $report = @"
تقرير تصدير سورس مشروع Flutter - الإصدار 2
============================================

اسم المشروع          : $projectName
مسار المشروع          : $resolvedProjectRoot
تاريخ التصدير         : $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
إصدار PowerShell      : $($PSVersionTable.PSVersion)
إصدار Flutter         : $flutterVersion
عدد الملفات المنسوخة  : $($copiedFiles.Count)
عدد العناصر المستبعدة : $($excludedItems.Count)
عدد تحذيرات النسخ     : $($copyWarnings.Count)

تضمين إعدادات Firebase الخاصة بالعميل: $firebaseConfigIncluded

تم استبعاد مجلدات Flutter المولدة والروابط الرمزية، ومنها:
- build
- .dart_tool
- .gradle
- Pods
- ephemeral
- .plugin_symlinks
- .symlinks
- node_modules

تم استبعاد الملفات الحساسة افتراضيًا، ومنها:
- JKS وKeystore
- key.properties
- local.properties
- ملفات .env
- Service Account JSON
- ملفات credentials وsecret

ملاحظة:
هذه النسخة مخصصة للفحص والتطوير، وليست نسخة احتياطية كاملة للمشروع.
"@

    Set-Content -LiteralPath $reportPath -Value $report -Encoding UTF8
    $copiedFiles | Sort-Object | Set-Content -LiteralPath $fileListPath -Encoding UTF8

    if ($excludedItems.Count -gt 0) {
        $excludedItems | Sort-Object | Set-Content -LiteralPath $excludedListPath -Encoding UTF8
    }
    else {
        Set-Content -LiteralPath $excludedListPath -Value "لا توجد عناصر مستبعدة." -Encoding UTF8
    }

    if ($copyWarnings.Count -gt 0) {
        $copyWarnings | Sort-Object | Set-Content -LiteralPath $warningsListPath -Encoding UTF8
    }
    else {
        Set-Content -LiteralPath $warningsListPath -Value "لا توجد تحذيرات نسخ." -Encoding UTF8
    }

    Write-Ok "تم إنشاء تقارير النسخة"

    Write-Step "ضغط المشروع"

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stagingRoot,
        $zipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
        throw "فشل إنشاء ملف ZIP."
    }

    $zipInfo = Get-Item -LiteralPath $zipPath
    $sizeMB = [Math]::Round($zipInfo.Length / 1MB, 2)
    $hash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256

    $hashFilePath = "$zipPath.sha256.txt"
    @(
        "File: $($zipInfo.Name)"
        "SizeMB: $sizeMB"
        "SHA256: $($hash.Hash)"
    ) | Set-Content -LiteralPath $hashFilePath -Encoding ASCII

    Write-Ok "تم إنشاء ملف ZIP"
    Write-Ok "الحجم: $sizeMB MB"
    Write-Ok "SHA256: $($hash.Hash)"

    if (-not $KeepStagingFolder.IsPresent) {
        Write-Step "تنظيف الملفات المؤقتة"
        Remove-PathSafely -Path $stagingRoot
        Write-Ok "تم حذف المجلد المؤقت"
    }
    else {
        Write-WarnMessage "تم الاحتفاظ بالمجلد المؤقت: $stagingRoot"
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor DarkCyan
    Write-Host "تمت العملية بنجاح" -ForegroundColor Green
    Write-Host "ملف ZIP:" -ForegroundColor White
    Write-Host $zipPath -ForegroundColor Yellow
    Write-Host ""
    Write-Host "ملف البصمة:" -ForegroundColor White
    Write-Host $hashFilePath -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor DarkCyan

    [PSCustomObject]@{
        ProjectRoot        = $resolvedProjectRoot
        ZipPath            = $zipPath
        HashFilePath       = $hashFilePath
        SizeMB             = $sizeMB
        SHA256             = $hash.Hash
        CopiedFileCount    = $copiedFiles.Count
        ExcludedItemCount  = $excludedItems.Count
        CopyWarningCount   = $copyWarnings.Count
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red

    if (Get-Variable -Name stagingRoot -ErrorAction SilentlyContinue) {
        if (-not $KeepStagingFolder.IsPresent) {
            try {
                Remove-PathSafely -Path $stagingRoot
            }
            catch {
                Write-WarnMessage "تعذر حذف المجلد المؤقت: $stagingRoot"
            }
        }
    }

    exit 1
}
