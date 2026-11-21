[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [string]$CompilerPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'
$versionLine = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$' | Select-Object -First 1
if (-not $versionLine) { throw 'pubspec.yaml 中找不到有效的应用版本。' }
$version = [regex]::Match($versionLine.Line, '(\d+\.\d+\.\d+)\+\d+').Groups[1].Value
$buildRoot = Join-Path $repoRoot 'build'
$releaseDir = Join-Path $buildRoot 'windows\x64\runner\Release'
$outputDir = Join-Path $repoRoot 'build\deliverables'
$setupPath = Join-Path $outputDir "MissionBook-Setup-$version-Windows-x64.exe"
$hashPath = "$setupPath.sha256.txt"
$issPath = Join-Path $PSScriptRoot 'installer\MissionBook.iss'

if (-not $SkipBuild) {
    Push-Location $repoRoot
    try {
        & flutter build windows --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw "Windows Release 构建失败，退出码 $LASTEXITCODE。" }
    }
    finally { Pop-Location }
}

$exePath = Join-Path $releaseDir 'mission_book.exe'
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "找不到 Windows Release 程序：$exePath"
}

if (-not $CompilerPath) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) { $CompilerPath = $command.Source }
}
if (-not $CompilerPath) {
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $candidatePaths = @(
        (Join-Path $programFilesX86 'Inno Setup 6\ISCC.exe'),
        (Join-Path $programFilesX86 'Inno Setup 7\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 7\ISCC.exe')
    )
    $CompilerPath = $candidatePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (-not $CompilerPath -or -not (Test-Path -LiteralPath $CompilerPath)) {
    throw '未找到 Inno Setup 6/7 编译器。请安装 Inno Setup，或用 -CompilerPath 指定 ISCC.exe。'
}
if (Test-Path -LiteralPath $setupPath) {
    throw "为避免覆盖已有交付物，停止：$setupPath 已存在。"
}
if (Test-Path -LiteralPath $hashPath) {
    throw "为避免覆盖已有交付物，停止：$hashPath 已存在。"
}
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

& $CompilerPath "/DBuildDir=$releaseDir" "/DAppVersion=$version" "/DOutputDir=$outputDir" $issPath
if ($LASTEXITCODE -ne 0) { throw "Inno Setup 编译失败，退出码 $LASTEXITCODE。" }
if (-not (Test-Path -LiteralPath $setupPath)) { throw 'Inno Setup 未生成预期的安装程序。' }

$hash = (Get-FileHash -LiteralPath $setupPath -Algorithm SHA256).Hash
[System.IO.File]::WriteAllText($hashPath, "$hash  $(Split-Path $setupPath -Leaf)`r`n", [System.Text.UTF8Encoding]::new($false))
Write-Output "安装程序：$setupPath"
Write-Output "SHA-256：$hash"


