param([string]$AppDirectory=(Join-Path $env:LOCALAPPDATA 'Programs/Lumaunt'),[string]$ReportPath=(Join-Path $PSScriptRoot 'x64-verification.txt'))
$ErrorActionPreference='Stop'
$processorCode=[int](Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Architecture)
$nativeArchitecture=switch($processorCode){9{'AMD64'}12{'ARM64'}default{'Other'}}
$mode=if($nativeArchitecture -eq 'AMD64'){'Native x64'}elseif($nativeArchitecture -eq 'ARM64'){'x64 under ARM emulation'}else{'Unsupported host architecture'}
$build=[Environment]::OSVersion.Version.Build
$lines=New-Object 'System.Collections.Generic.List[string]'
$lines.Add("Host mode: $mode");$lines.Add("Windows build: $build")
try {
 if($nativeArchitecture -notin @('AMD64','ARM64')){throw 'This test needs a 64-bit Windows PC.'}
 if($build -lt 19041){throw 'This preview installer targets Windows build 19041 or later.'}
 & "$PSScriptRoot/check-package.ps1" -Runtime win-x64 -AppDirectory $AppDirectory | ForEach-Object {$lines.Add($_)}
 $process=Start-Process (Join-Path $AppDirectory 'Lumaunt.exe') -ArgumentList '--check-windows-features' -PassThru
 if(-not $process.WaitForExit(120000)){throw 'Runtime checks did not finish within two minutes. No account data was accessed.'}
 $process.Refresh()
 if($process.ExitCode -ne 0){throw 'Isolated runtime checks failed. Review windows-feature-check.txt beside Lumaunt.exe locally.'}
 $result=Get-Content (Join-Path $AppDirectory 'windows-feature-check.txt') -Raw
 if(-not $result.StartsWith('PASS:')){throw 'Runtime check did not produce a passing report.'}
 $lines.Add('PASS: isolated SDK, protected storage, images, presets, themes and UI runtime checks.')
 $lines.Add('No Discord login, live publishing, public uploads or Sentry delivery were performed.')
 $lines.Add($(if($mode -eq 'Native x64'){'PASS: native x64 runtime checks. Live-account QA remains required.'}else{'PASS: emulated x64 runtime checks only. Physical Intel/AMD testing remains required.'}))
} catch {
 $lines.Add('FAIL: '+$_.Exception.Message)
 $lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
 $lines | Write-Output
 exit 1
}
$lines | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$lines | Write-Output
