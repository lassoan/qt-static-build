<#
Build a static qtbase with MSVC and package it as <Name>.tar.xz.

Must be run from an MSVC developer environment for the target architecture.
The archive contains a single top-level <Name> directory holding the Qt
install tree. A smoke test project is built against it before packaging.

Usage:

  build-qt6.ps1 -QtVersion <version> -Name <name> -OutputDir <dir> [-WorkDir <dir>]
#>
param(
  [Parameter(Mandatory)] [string] $QtVersion,
  [Parameter(Mandatory)] [string] $Name,
  [Parameter(Mandatory)] [string] $OutputDir,
  # Short paths avoid exceeding MAX_PATH while building Qt
  [string] $WorkDir = "C:\q"
)

$ErrorActionPreference = "Stop"

function Invoke-Checked {
  $Command, $Arguments = $args
  & $Command @Arguments
  if ($LastExitCode -ne 0) { throw "Command failed with exit code ${LastExitCode}: $args" }
}

$SmokeDir = Join-Path $PSScriptRoot "..\tests\smoke"
$OutputDir = (New-Item -ItemType Directory -Force $OutputDir).FullName
$SrcDir = Join-Path $WorkDir "s"
$BuildDir = Join-Path $WorkDir "b"
$Prefix = Join-Path $WorkDir $Name
New-Item -ItemType Directory -Force $SrcDir, $BuildDir | Out-Null

$QtMinor = $QtVersion.Substring(0, $QtVersion.LastIndexOf("."))
$Archive = Join-Path $WorkDir "qtbase-everywhere-src-$QtVersion.tar.xz"
$Url = "https://download.qt.io/archive/qt/$QtMinor/$QtVersion/submodules/qtbase-everywhere-src-$QtVersion.tar.xz"

Write-Host "Downloading $Url"
Invoke-Checked curl.exe -fsSL -o $Archive $Url
$ExpectedSha256 = ((Invoke-Checked curl.exe -fsSL "$Url.sha256") -split "\s+")[0]
$ActualSha256 = (Get-FileHash -Algorithm SHA256 $Archive).Hash
if ($ActualSha256 -ne $ExpectedSha256) {
  throw "SHA256 mismatch for ${Archive}: expected $ExpectedSha256, got $ActualSha256"
}
Invoke-Checked C:\Windows\System32\tar.exe -xf $Archive -C $SrcDir --strip-components=1

Push-Location $BuildDir
Invoke-Checked "$SrcDir\configure.bat" `
  -prefix $Prefix `
  -release `
  -static `
  -static-runtime `
  -nomake examples `
  -nomake tests `
  -no-opengl `
  -no-dbus `
  -no-icu `
  -no-openssl `
  -qt-zlib `
  -qt-libpng `
  -qt-libjpeg `
  -qt-pcre `
  -qt-harfbuzz
Invoke-Checked cmake --build . --parallel
Invoke-Checked cmake --install .
Pop-Location

Invoke-Checked cmake `
  -S $SmokeDir `
  -B (Join-Path $WorkDir "smoke") `
  -G Ninja `
  "-DCMAKE_BUILD_TYPE:STRING=Release" `
  "-DCMAKE_MSVC_RUNTIME_LIBRARY:STRING=MultiThreaded" `
  "-DCMAKE_PREFIX_PATH:PATH=$Prefix"
Invoke-Checked cmake --build (Join-Path $WorkDir "smoke")

Push-Location $WorkDir
Invoke-Checked cmake -E tar cJf (Join-Path $OutputDir "$Name.tar.xz") $Name
Pop-Location
Write-Host "Created $OutputDir\$Name.tar.xz"
