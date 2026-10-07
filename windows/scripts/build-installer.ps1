param([ValidateSet("win-arm64","win-x64")][string]$Runtime="win-arm64",[string]$Compiler)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$output="$root/artifacts/$Runtime"
foreach($file in @('Lumaunt.exe','lumaunt_discord.dll','discord_partner_sdk.dll','discord_krisp.dll','License-Notices.txt','vcruntime140.dll','msvcp140.dll')) {
 if(-not(Test-Path "$output/$file")) {throw "Missing release runtime file: $file. Run the native and UI builds first."}
}
& "$PSScriptRoot/check-package.ps1" -Runtime $Runtime -AppDirectory $output
if(-not $Compiler) {
 $command=Get-Command ISCC -ErrorAction SilentlyContinue
 if($command) {$Compiler=$command.Source}
 else {
  $Compiler=@("${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe","$env:ProgramFiles/Inno Setup 6/ISCC.exe","$env:LOCALAPPDATA/LumauntBuildTools/Inno Setup 6/ISCC.exe") | Where-Object {Test-Path $_} | Select-Object -First 1
 }
}
if(-not $Compiler) {throw 'Install Inno Setup 6.7 or newer from its official source, or pass -Compiler with the ISCC.exe path.'}
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo("$output/Lumaunt.exe").ProductVersion.Split('+')[0]
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Unexpected application version: $version" }
& $Compiler "/DVersion=$version" "/DRuntime=$Runtime" "/DSourceDir=$output" "$root/installer/Lumaunt.iss"
if($LASTEXITCODE -ne 0) {throw 'Installer compilation failed'}
Write-Host 'Unsigned development installer created; no release has been published.'
