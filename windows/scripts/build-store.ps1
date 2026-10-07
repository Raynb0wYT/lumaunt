param([string]$IdentityPath,[switch]$TestIdentity,[string]$MakeAppx)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
if($TestIdentity -and $IdentityPath){throw 'Choose real identity or -TestIdentity, not both.'}
if($TestIdentity) {
 $identity=[pscustomobject]@{packageName='Lumaunt.PackagingTest';publisher='CN=Lumaunt Packaging Test';publisherDisplayName='Lumaunt Packaging Test';displayName='Lumaunt'}
 $label='packaging-test'
} else {
 if(-not $IdentityPath){throw 'Supply Partner Center product identity via -IdentityPath, or -TestIdentity for non-submittable validation.'}
 $identity=Get-Content -LiteralPath $IdentityPath -Raw | ConvertFrom-Json
 $label='store-candidate'
}
foreach($field in @('packageName','publisher','publisherDisplayName','displayName')) {
 if([string]::IsNullOrWhiteSpace($identity.$field) -or $identity.$field -match 'REPLACE_WITH'){throw "Missing product identity: $field"}
}
if($identity.packageName -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{2,49}$'){throw 'Invalid Partner Center package identity.'}
if($identity.publisher -notmatch '^CN='){throw 'Use the exact Partner Center publisher, starting CN=.'}
if(-not $MakeAppx) {
 $kits="${env:ProgramFiles(x86)}\Windows Kits\10\bin"
 $MakeAppx=Get-ChildItem "$kits\*\arm64\makeappx.exe","$kits\*\x64\makeappx.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if(-not $MakeAppx -or -not(Test-Path -LiteralPath $MakeAppx)){throw 'Windows SDK MakeAppx is required.'}
Add-Type -AssemblyName System.Drawing
$out=Join-Path $root "artifacts/store/$label"
$bundleInput=Join-Path $out 'bundle-input'
New-Item -ItemType Directory -Force $bundleInput | Out-Null
foreach($runtime in @('win-x64','win-arm64')) {
 $source=Join-Path $root "artifacts/$runtime"
 & "$PSScriptRoot/check-package.ps1" -Runtime $runtime -AppDirectory $source
 $productVersion=[Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $source 'Lumaunt.exe')).ProductVersion.Split('+')[0]
 $version=[Version]$productVersion
 if($version.Build -lt 0){throw 'Invalid published version metadata.'}
 $packageVersion="{0}.{1}.{2}.0" -f $version.Major,$version.Minor,$version.Build
 if($previousVersion -and $previousVersion -ne $packageVersion){throw 'ARM64 and x64 app versions differ.'}
 $previousVersion=$packageVersion
 $stage=Join-Path $out "$runtime-stage"
 # Only generated, private staging folders are replaced; publish outputs stay intact.
 if(Test-Path $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
 New-Item -ItemType Directory -Force $stage | Out-Null
 Get-ChildItem -LiteralPath $source | Where-Object {$_.Name -notlike '*.pdb' -and $_.Name -notlike '*-check.txt'} | Copy-Item -Destination $stage -Recurse -Force
 $assets=Join-Path $stage 'Assets';New-Item -ItemType Directory -Force $assets | Out-Null
 $icon=[Drawing.Image]::FromFile((Join-Path $root 'Lumaunt.Windows/Assets/Lumaunt.png'))
 try {
  foreach($spec in @(@('StoreLogo.png',50),@('Square150x150Logo.png',150),@('Square44x44Logo.png',44))) {
   $size=[int]$spec[1];$bitmap=New-Object Drawing.Bitmap($size,$size);$graphics=[Drawing.Graphics]::FromImage($bitmap)
   try {
    $graphics.Clear([Drawing.Color]::Transparent)
    $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($icon,0,0,$size,$size)
    $bitmap.Save((Join-Path $assets $spec[0]),[Drawing.Imaging.ImageFormat]::Png)
   } finally {$graphics.Dispose();$bitmap.Dispose()}
  }
 } finally {$icon.Dispose()}
 $minimum=if($runtime -eq 'win-arm64'){'10.0.22000.0'}else{'10.0.19041.0'}
 $manifest=Get-Content "$root/store/AppxManifest.template.xml" -Raw
 $values=@{'PACKAGE_NAME'=$identity.packageName;'PUBLISHER'=$identity.publisher;'PUBLISHER_DISPLAY_NAME'=$identity.publisherDisplayName;'DISPLAY_NAME'=$identity.displayName;'VERSION'=$packageVersion;'ARCHITECTURE'=$runtime.Replace('win-','');'MIN_VERSION'=$minimum}
 foreach($key in $values.Keys){$manifest=$manifest.Replace("@$key@",[Security.SecurityElement]::Escape([string]$values[$key]))}
 $manifest | Set-Content (Join-Path $stage 'AppxManifest.xml') -Encoding UTF8
 $package=Join-Path $bundleInput "Lumaunt-$packageVersion-$runtime.msix"
 & $MakeAppx pack /d $stage /p $package /o
 if($LASTEXITCODE -ne 0){throw "MakeAppx validation/pack failed: $runtime"}
 $unpack=Join-Path $out "$runtime-unpacked"
 & $MakeAppx unpack /p $package /d $unpack /o
 if($LASTEXITCODE -ne 0){throw "Unpack verification failed: $runtime"}
 & "$PSScriptRoot/check-package.ps1" -Runtime $runtime -AppDirectory $unpack
 [xml]$verifiedManifest=Get-Content (Join-Path $unpack 'AppxManifest.xml') -Raw
 if($verifiedManifest.Package.Identity.Name -cne $identity.packageName -or
    $verifiedManifest.Package.Identity.Publisher -cne $identity.publisher -or
    $verifiedManifest.Package.Properties.PublisherDisplayName -cne $identity.publisherDisplayName){throw "Unpacked Store identity mismatch: $runtime"}
 Write-Output "PASS: $runtime unpacked Store identity matches configuration."
 foreach($file in @('Lumaunt.exe','lumaunt_discord.dll','discord_partner_sdk.dll','discord_krisp.dll')) {
  if((Get-FileHash (Join-Path $source $file)).Hash -ne (Get-FileHash (Join-Path $unpack $file)).Hash){throw "Packaged binary changed: $file"}
 }
}
Get-ChildItem $bundleInput -Filter '*.msix' | Copy-Item -Destination $out -Force
Get-ChildItem $out -File | Where-Object {$_.Extension -in @('.msix','.msixbundle')} | ForEach-Object {"$((Get-FileHash $_.FullName -Algorithm SHA256).Hash)  $($_.Name)"} | Set-Content (Join-Path $out 'SHA256SUMS.txt')
Write-Output 'PASS: unsigned MSIX packages packed, unpacked and checked.'
if($TestIdentity){Write-Output 'TEST IDENTITY ONLY: not signed, not installable by ordinary users, not a Store submission.'}
else {Write-Output 'Candidate only: packaged runtime and Store certification checks remain required before submission.'}
