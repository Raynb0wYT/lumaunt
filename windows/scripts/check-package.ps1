param([ValidateSet('win-x64','win-arm64')][string]$Runtime='win-x64',[string]$AppDirectory)
$ErrorActionPreference='Stop'
if (-not $AppDirectory) { $AppDirectory=Join-Path (Split-Path $PSScriptRoot) "artifacts/$Runtime" }
$expected=if($Runtime -eq 'win-x64'){0x8664}else{0xAA64}
$required=@('Lumaunt.exe','lumaunt_discord.dll','discord_partner_sdk.dll','discord_krisp.dll','coreclr.dll','clrjit.dll','hostfxr.dll','hostpolicy.dll','libSkiaSharp.dll','vcruntime140.dll','msvcp140.dll')
foreach($name in $required) {
 $path=Join-Path $AppDirectory $name
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing required runtime file: $name"}
 $stream=[IO.File]::OpenRead($path);$reader=New-Object IO.BinaryReader($stream)
 try {
  if($reader.ReadUInt16() -ne 0x5A4D){throw "Invalid executable: $name"}
  $stream.Position=0x3C;$pe=$reader.ReadInt32()
  if($pe -lt 64 -or $pe -gt ($stream.Length-26)){throw "Invalid executable header: $name"}
  $stream.Position=$pe
  if($reader.ReadUInt32() -ne 0x4550){throw "Invalid PE signature: $name"}
  $machine=$reader.ReadUInt16()
  if($machine -ne $expected){throw ('Wrong architecture in {0}: expected {1:X4}, found {2:X4}' -f $name,$expected,$machine)}
 } finally {$reader.Dispose();$stream.Dispose()}
}
if(-not(Test-Path (Join-Path $AppDirectory 'License-Notices.txt'))){throw 'SDK license notices are missing.'}
Write-Output "PASS: $Runtime executable, Discord SDK, .NET, image decoder and VC runtime architectures match."
