param([Parameter(Mandatory=$true)][string]$SdkRoot, [ValidateSet("ARM64", "x64")][string]$Architecture = "ARM64", [string]$ProjectRoot)
$ErrorActionPreference = "Stop"
$root = if ($ProjectRoot) { $ProjectRoot } else { Split-Path $PSScriptRoot }
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if ($cmake) { $cmakePath = $cmake.Source } else {
 $vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
 if (-not (Test-Path $vswhere)) { throw "Install Visual Studio C++ tools and CMake." }
 $cmakePath = & $vswhere -latest -products '*' -find 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe' | Select-Object -First 1
 if (-not $cmakePath) { throw "CMake was not found in Visual Studio." }
}
$build = "$root/native/build/$Architecture"
& $cmakePath -S "$root/native" -B $build -A $Architecture "-DDISCORD_SDK_ROOT=$SdkRoot"
if ($LASTEXITCODE -ne 0) { throw "Native configuration failed." }
& $cmakePath --build $build --config Release
if ($LASTEXITCODE -ne 0) { throw "Native build failed." }
& "$build/Release/lumaunt-discord-smoke.exe" --self-check
if ($LASTEXITCODE -ne 0) { throw "SDK lifecycle self-check failed." }

& "$build/Release/lumaunt-artwork-check.exe"
if ($LASTEXITCODE -ne 0) { throw "Presence artwork checks failed." }
