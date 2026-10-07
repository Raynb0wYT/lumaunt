param([Parameter(Mandatory=$true)][string]$PackagePath,[string]$ReportDirectory)
$ErrorActionPreference='Stop'
$PackagePath=(Resolve-Path -LiteralPath $PackagePath).Path
$runner="${env:ProgramFiles(x86)}\Windows Kits\10\App Certification Kit\appcert.exe"
if(-not(Test-Path -LiteralPath $runner)){throw 'Install the Windows SDK App Certification Kit on an Intel/AMD Windows PC. The current ARM VM SDK installer skips the runner.'}
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run from an elevated PowerShell in your signed-in desktop session, as Microsoft requires.'}
if([Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0){throw 'Run in an active signed-in desktop session, not Session 0.'}
if(-not $ReportDirectory){$ReportDirectory=Join-Path (Split-Path $PSScriptRoot) 'artifacts/verification/certification'}
New-Item -ItemType Directory -Force $ReportDirectory | Out-Null
$report=Join-Path $ReportDirectory ('certification-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.xml')
& $runner reset
if($LASTEXITCODE -ne 0){throw 'Certification kit reset failed.'}
& $runner test -appxpackagepath $PackagePath -reportoutputpath $report
$code=$LASTEXITCODE
if(-not(Test-Path -LiteralPath $report)){throw "Certification did not produce a report (exit $code). Package installation may require a locally trusted development signature; do not disable Windows security."}
Write-Output "Report: $report"
Write-Output "Kit exit: $code. Review every result in the XML/HTML report; report creation alone is not a pass."
if($code -ne 0){throw "Certification returned exit $code. Review the report before submission."}
