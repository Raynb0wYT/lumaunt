#ifndef Runtime
  #define Runtime "win-arm64"
#endif
#ifndef Version
  #define Version "1.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\artifacts\" + Runtime
#endif
[Setup]
AppId={{4D981754-EDC9-4ED2-A4B3-6581677FF75D}
AppName=Lumaunt
AppVersion={#Version}
AppVerName=Lumaunt {#Version}
DefaultDirName={localappdata}\Programs\Lumaunt
DefaultGroupName=Lumaunt
PrivilegesRequired=lowest
#if Runtime == "win-arm64"
MinVersion=10.0.22000
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
MinVersion=10.0.19041
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
OutputDir=..\artifacts\installers
OutputBaseFilename=Lumaunt-{#Version}-{#Runtime}-setup
SetupIconFile=..\Lumaunt.Windows\Assets\Lumaunt.ico
UninstallDisplayIcon={app}\Lumaunt.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb,*-check.txt"
[Icons]
Name: "{group}\Lumaunt"; Filename: "{app}\Lumaunt.exe"
[UninstallDelete]
; Saved credentials, presets and image ownership stay in LocalAppData\Lumaunt.
; They are deliberately not removed by uninstall.

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    RegDeleteValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Run', 'LumauntWindows');
end;
