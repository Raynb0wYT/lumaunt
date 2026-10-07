param([ValidateSet("win-x64", "win-arm64")][string]$Runtime = "win-x64")
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
$dotnetPath = if ($dotnet) { $dotnet.Source } else { Join-Path $env:LOCALAPPDATA 'LumauntBuildTools/dotnet-arm64/dotnet.exe' }
if (-not (Test-Path $dotnetPath)) { throw "Install the .NET 10 SDK." }
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1' 
& $dotnetPath run --project "$root/Lumaunt.Core.Checks" --configuration Release
if ($LASTEXITCODE -ne 0) { throw "Core checks failed" }
& $dotnetPath publish "$root/Lumaunt.Windows" --configuration Release --runtime $Runtime --self-contained true --output "$root/artifacts/$Runtime"
if ($LASTEXITCODE -ne 0) { throw "Windows UI build failed" }
$architecture = if ($Runtime -eq 'win-arm64') { 'ARM64' } else { 'x64' }
$native = "$root/native/build/$architecture/Release"
if (Test-Path "$native/lumaunt_discord.dll") {
 foreach ($file in @('lumaunt_discord.dll', 'discord_partner_sdk.dll', 'discord_krisp.dll')) {
  if (-not (Test-Path "$native/$file")) { throw "Native SDK runtime file missing: $file" }
  Copy-Item "$native/$file" "$root/artifacts/$Runtime/$file" -Force
 }
 if (Test-Path "$native/License-Notices.txt") { Copy-Item "$native/License-Notices.txt" "$root/artifacts/$Runtime/License-Notices.txt" -Force }
 $vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
 if (-not (Test-Path $vswhere)) { throw "Visual Studio redistribution files are required for the native SDK." }
 $vs = & $vswhere -latest -products '*' -property installationPath | Select-Object -First 1
 $crtArch = if ($Runtime -eq 'win-arm64') { 'arm64' } else { 'x64' }
 $crt = Get-ChildItem "$vs/VC/Redist/MSVC/*/$crtArch/Microsoft.VC143.CRT" -Directory | Sort-Object FullName -Descending | Select-Object -First 1
 if (-not $crt) { throw "Matching Visual C++ runtime files were not found." }
 Copy-Item "$($crt.FullName)/*.dll" "$root/artifacts/$Runtime" -Force
 $check = Start-Process "$root/artifacts/$Runtime/Lumaunt.exe" -ArgumentList '--check-windows-features' -Wait -PassThru
 Get-Content "$root/artifacts/$Runtime/windows-feature-check.txt"
 if ($check.ExitCode -ne 0) { throw "Windows runtime checks failed" }
 Write-Host "Discord, publishing and protected saved sessions are available in this development build."
} else { Write-Host "UI preview only; build the matching native bridge to enable Discord Connect." }
Write-Host "Development build; not a release installer."
